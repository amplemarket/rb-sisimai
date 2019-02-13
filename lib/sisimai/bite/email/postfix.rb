module Sisimai::Bite::Email
  # Sisimai::Bite::Email::Postfix parses a bounce email which created by
  # Postfix. Methods in the module are called from only Sisimai::Message.
  module Postfix
    class << self
      # Imported from p5-Sisimail/lib/Sisimai/Bite/Email/Postfix.pm
      require 'sisimai/bite/email'

      # Postfix manual - bounce(5) - http://www.postfix.org/bounce.5.html
      Indicators = Sisimai::Bite::Email.INDICATORS
      StartingOf = { rfc822: ['Content-Type: message/rfc822', 'Content-Type: text/rfc822-headers'] }.freeze
      MarkingsOf = {
        message: %r{\A(?>
           [ ]+The[ ](?:
             Postfix[ ](?:
               program\z              # The Postfix program
              |on[ ].+[ ]program\z    # The Postfix on <os name> program
              )
            |\w+[ ]Postfix[ ]program\z  # The <name> Postfix program
            |mail[ \t]system\z             # The mail system
            |\w+[ \t]program\z             # The <custmized-name> program
            )
          |This[ ]is[ ]the[ ](?:
             Postfix[ ]program          # This is the Postfix program
            |\w+[ ]Postfix[ ]program    # This is the <name> Postfix program
            |\w+[ ]program              # This is the <customized-name> Postfix program
            |mail[ ]system[ ]at[ ]host  # This is the mail system at host <hostname>.
            )
          )
        }x,
      }.freeze

      def description; return 'Postfix'; end
      def smtpagent;   return Sisimai::Bite.smtpagent(self); end
      def headerlist;  return []; end

      # Parse bounce messages from Postfix
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
        # :from => %r/ [(]Mail Delivery System[)]\z/,
        return nil unless mhead['subject'] == 'Undelivered Mail Returned to Sender'

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
        anotherset = {}     # Another error information
        v = nil

        while e = hasdivided.shift do
          # Save the current line for the next loop
          havepassed << e
          p = havepassed[-2]

          if readcursor == 0
            # Beginning of the bounce message or message/delivery-status part
            if e =~ MarkingsOf[:message]
              readcursor |= Indicators[:deliverystatus]
              next
            end
          end

          if (readcursor & Indicators[:'message-rfc822']) == 0
            # Beginning of the original message part(message/rfc822)
            if e.start_with?(StartingOf[:rfc822][0], StartingOf[:rfc822][1])
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
              next unless o = Sisimai::RFC1894.field(e)
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
                v['spec'] = 'SMTP' if v['spec'] == 'X-POSTFIX'
                v['diagnosis'] = o[2]
              else
                # Other DSN fields defined in RFC3464
                next unless fieldtable.key?(o[0])
                v[fieldtable[o[0]]] = o[2]

                next unless f == 1
                permessage[fieldtable[o[0]]] = o[2]
              end
            else
              # If you do so, please include this problem report. You can
              # delete your own text from the attached returned message.
              #
              #           The mail system
              #
              # <userunknown@example.co.jp>: host mx.example.co.jp[192.0.2.153] said: 550
              # 5.1.1 <userunknown@example.co.jp>... User Unknown (in reply to RCPT TO
              # command)
              if p.start_with?('Diagnostic-Code:') && cv = e.match(/\A[ \t]+(.+)\z/)
                # Continued line of the value of Diagnostic-Code header
                v['diagnosis'] << ' ' << cv[1]
                havepassed[-1] = 'Diagnostic-Code: ' << e

              elsif cv = e.match(/\A(X-Postfix-Sender):[ ]*rfc822;[ ]*(.+)\z/)
                # X-Postfix-Sender: rfc822; shironeko@example.org
                rfc822list << cv[1] << ': ' << cv[2]

              else
                if cv = e.match(/[ \t][(]in reply to ([A-Z]{4}).*/)
                  # 5.1.1 <userunknown@example.co.jp>... User Unknown (in reply to RCPT TO
                  commandset << cv[1]
                  anotherset['diagnosis'] ||= ''
                  anotherset['diagnosis'] << ' ' << e

                elsif cv = e.match(/([A-Z]{4})[ \t]*.*command[)]\z/)
                  # to MAIL command)
                  commandset << cv[1]
                  anotherset['diagnosis'] ||= ''
                  anotherset['diagnosis'] << ' ' << e

                else
                    # Alternative error message and recipient
                    if cv = e.match(/\A[<]([^ ]+[@][^ ]+)[>] [(]expanded from [<](.+)[>][)]:[ \t]*(.+)\z/)
                      # <r@example.ne.jp> (expanded from <kijitora@example.org>): user ...
                      anotherset['recipient'] = cv[1]
                      anotherset['alias']     = cv[2]
                      anotherset['diagnosis'] = cv[3]

                    elsif cv = e.match(/\A[<]([^ ]+[@][^ ]+)[>]:(.*)\z/)
                      # <kijitora@exmaple.jp>: ...
                      anotherset['recipient'] = cv[1]
                      anotherset['diagnosis'] = cv[2]
                    else
                      # Get error message continued from the previous line
                      next unless anotherset['diagnosis']
                      if e =~ /\A[ \t]{4}(.+)\z/
                        #    host mx.example.jp said:...
                        anotherset['diagnosis'] << ' ' << e
                      end
                    end
                  end
              end
            end
          end # End of message/delivery-status
        end

        unless recipients > 0
          # Fallback: set recipient address from error message
          unless anotherset['recipient'].to_s.empty?
            # Set recipient address
            dscontents[-1]['recipient'] = anotherset['recipient']
            recipients += 1
          end
        end
        return nil unless recipients > 0

        dscontents.each do |e|
          # Set default values if each value is empty.
          e['lhost'] ||= permessage['rhost']
          permessage.each_key { |a| e[a] ||= permessage[a] || '' }

          e['agent']   = self.smtpagent
          e['command'] = commandset.shift || ''

          if anotherset['diagnosis']
            # Copy alternative error message
            e['diagnosis'] = anotherset['diagnosis'] unless e['diagnosis']

            if e['diagnosis'] =~ /\A\d+\z/
              e['diagnosis'] = anotherset['diagnosis']
            else
              # More detailed error message is in "anotherset"
              as = nil  # status
              ar = nil  # replycode

              e['status']    ||= ''
              e['replycode'] ||= ''

              if e['status'] == '' || e['status'].start_with?('4.0.0', '5.0.0')
                # Check the value of D.S.N. in anotherset
                as = Sisimai::SMTP::Status.find(anotherset['diagnosis'])
                if as && as[-3, 3] != '0.0'
                  # The D.S.N. is neither an empty nor *.0.0
                  e['status'] = as
                end
              end

              if e['replycode'] == '' || e['replycode'].start_with?('400', '500')
                # Check the value of SMTP reply code in anotherset
                ar = Sisimai::SMTP::Reply.find(anotherset['diagnosis'])
                if ar && ar[-2, 2].to_i != 0
                  # The SMTP reply code is neither an empty nor *00
                  e['replycode'] = ar
                end
              end

              if (as || ar) && (anotherset['diagnosis'].size > e['diagnosis'].size)
                # Update the error message in e['diagnosis']
                e['diagnosis'] = anotherset['diagnosis']
              end
            end
          end

          e['diagnosis'] = Sisimai::String.sweep(e['diagnosis'])
          e['spec']    ||= 'SMTP' if e['diagnosis'] =~ /host .+ said:/
          e.each_key { |a| e[a] ||= '' }
        end

        rfc822part = Sisimai::RFC5322.weedout(rfc822list)
        return { 'ds' => dscontents, 'rfc822' => rfc822part }
      end

    end
  end
end

