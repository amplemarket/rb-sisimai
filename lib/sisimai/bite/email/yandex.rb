module Sisimai::Bite::Email
  # Sisimai::Bite::Email::Yandex parses a bounce email which created by
  # Yandex.Mail. Methods in the module are called from only Sisimai::Message.
  module Yandex
    class << self
      # Imported from p5-Sisimail/lib/Sisimai/Bite/Email/Yandex.pm
      require 'sisimai/bite/email'

      Indicators = Sisimai::Bite::Email.INDICATORS
      StartingOf = {
        message: ['This is the mail system at host yandex.ru.'],
        rfc822:  ['Content-Type: message/rfc822'],
      }.freeze

      def description; return 'Yandex.Mail: http://www.yandex.ru'; end
      def smtpagent;   return Sisimai::Bite.smtpagent(self); end

      # X-Yandex-Front: mxback1h.mail.yandex.net
      # X-Yandex-TimeMark: 1417885948
      # X-Yandex-Uniq: 92309766-f1c8-4bd4-92bc-657c75766587
      # X-Yandex-Spam: 1
      # X-Yandex-Forward: 10104c00ad0726da5f37374723b1e0c8
      # X-Yandex-Queue-ID: 367D79E130D
      # X-Yandex-Sender: rfc822; shironeko@yandex.example.com
      def headerlist;  return ['X-Yandex-Uniq']; end

      # Parse bounce messages from Yandex.Mail
      # @param         [Hash] mhead       Message headers of a bounce email
      # @options mhead [String] from      From header
      # @options mhead [String] date      Date header
      # @options mhead [String] subject   Subject header
      # @options mhead [Array]  received  Received headers
      # @options mhead [String] others    Other required headers
      # @param         [String] mbody     Message body of a bounce email
      # @return        [Hash, Nil]        Bounce data list and message/rfc822
      #                                   part or nil if it failed to parse or
      #                                   the arguments are missing
      def scan(mhead, mbody)
        return nil unless mhead['x-yandex-uniq']
        return nil unless mhead['from'] == 'mailer-daemon@yandex.ru'

        require 'sisimai/rfc1894'
        fieldtable = Sisimai::RFC1894.FIELDTABLE
        permessage = {}     # (Hash) Store values of each Per-Message field

        dscontents = [Sisimai::Bite.DELIVERYSTATUS]
        hasdivided = mbody.split("\n")
        havepassed = ['']
        rfc822list = []     # (Array) Each line in message/rfc822 part string
        blanklines = 0      # (Integer) The number of blank lines
        readcursor = 0      # (Integer) Points the current cursor position
        recipients = 0      # (Integer) The number of 'Final-Recipient' header
        commandset = []     # (Array) ``in reply to * command'' list
        v = nil

        while e = hasdivided.shift do
          # Save the current line for the next loop
          havepassed << e
          p = havepassed[-2]

          if readcursor == 0
            # Beginning of the bounce message or message/delivery-status part
            if e.start_with?(StartingOf[:message][0])
              readcursor |= Indicators[:deliverystatus]
              next
            end
          end

          if (readcursor & Indicators[:'message-rfc822']) == 0
            # Beginning of the original message part(message/rfc822)
            if e.start_with?(StartingOf[:rfc822][0])
              readcursor |= Indicators[:'message-rfc822']
              next
            end
          end

          if readcursor & Indicators[:'message-rfc822'] > 0
            # message/rfc822 OR text/rfc822-headers part
            if e.empty?
              blanklines += 1
              break if blanklines > 1
              next
            end
            rfc822list << e
          else
            # message/delivery-status part
            next if (readcursor & Indicators[:deliverystatus]) == 0
            next if e.empty?

            if f = Sisimai::RFC1894.match(e)
              # "e" matched with any field defined in RFC3464
              o = Sisimai::RFC1894.field(e) || next
              v = dscontents[-1]

              if o[-1] == 'addr'
                # Final-Recipient: rfc822; kijitora@example.jp
                # X-Actual-Recipient: rfc822; kijitora@example.co.jp
                if o[0] == 'final-recipient'
                  # Final-Recipient: rfc822; kijitora@example.jp
                  if v['recipient']
                    # There are multiple recipient addresses in the message body.
                    dscontents << Sisimai::Bite.DELIVERYSTATUS
                    v = dscontents[-1]
                  end
                  v['recipient'] = o[2]
                  recipients += 1
                else
                  # X-Actual-Recipient: rfc822; kijitora@example.co.jp
                  v['alias'] = o[2]
                end
              elsif o[-1] == 'code'
                # Diagnostic-Code: SMTP; 550 5.1.1 <userunknown@example.jp>... User Unknown
                v['spec'] = o[1]
                v['diagnosis'] = o[2]
              else
                # Other DSN fields defined in RFC3464
                next unless fieldtable.key?(o[0].to_sym)
                v[fieldtable[o[0].to_sym]] = o[2]

                next unless f == 1
                permessage[fieldtable[o[0].to_sym]] = o[2]
              end
            else
              # The line does not begin with a DSN field defined in RFC3464
              if cv = e.match(/[ \t][(]in reply to .*([A-Z]{4}).*/)
                # 5.1.1 <userunknown@example.co.jp>... User Unknown (in reply to RCPT TO
                commandset << cv[1]

              elsif cv = e.match(/([A-Z]{4})[ \t]*.*command[)]\z/)
                # to MAIL command)
                commandset << cv[1]
              else
                # Continued line of the value of Diagnostic-Code field
                next unless p.start_with?('Diagnostic-Code:')
                next unless cv = e.match(/\A[ \t]+(.+)\z/)
                v['diagnosis'] << ' ' << cv[1]
                havepassed[-1] = 'Diagnostic-Code: ' << e
              end
            end
          end # End of message/delivery-status
        end
        return nil unless recipients > 0

        dscontents.each do |e|
          # Set default values if each value is empty.
          e['lhost'] ||= permessage['rhost']
          permessage.each_key { |a| e[a] ||= permessage[a] || '' }

          e['command']   = commandset.shift || ''
          e['diagnosis'] = Sisimai::String.sweep(e['diagnosis'].gsub(/\\n/, ''))
          e['agent']     = self.smtpagent
        end

        rfc822part = Sisimai::RFC5322.weedout(rfc822list)
        return { 'ds' => dscontents, 'rfc822' => rfc822part }
      end

    end
  end
end

