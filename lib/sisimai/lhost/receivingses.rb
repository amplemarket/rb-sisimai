module Sisimai::Lhost
  # Sisimai::Lhost::ReceivingSES parses a bounce email which created
  # by Amazon Simple Email Service. Methods in the module are called from
  # only Sisimai::Message.
  module ReceivingSES
    class << self
      # Imported from p5-Sisimail/lib/Sisimai/Lhost/ReceivingSES.pm
      require 'sisimai/lhost'

      # https://aws.amazon.com/ses/
      Indicators = Sisimai::Lhost.INDICATORS
      ReBackbone = %r|^content-type:[ ]text/rfc822-headers|.freeze
      StartingOf = { message: ['This message could not be delivered.'] }.freeze
      MessagesOf = {
        # The followings are error messages in Rule sets/*/Actions/Template
        'filtered'     => ['Mailbox does not exist'],
        'mesgtoobig'   => ['Message too large'],
        'mailboxfull'  => ['Mailbox full'],
        'contenterror' => ['Message content rejected'],
      }.freeze

      # Parse bounce messages from Amazon SES/Receiving
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
      def make(mhead, mbody)
        # X-SES-Outgoing: 2015.10.01-54.240.27.7
        # Feedback-ID: 1.us-west-2.HX6/J9OVlHTadQhEu1+wdF9DBj6n6Pa9sW5Y/0pSOi8=:AmazonSES
        return nil unless mhead['x-ses-outgoing']

        require 'sisimai/rfc1894'
        fieldtable = Sisimai::RFC1894.FIELDTABLE
        permessage = {}     # (Hash) Store values of each Per-Message field

        dscontents = [Sisimai::Lhost.DELIVERYSTATUS]
        emailsteak = Sisimai::RFC5322.fillet(mbody, ReBackbone)
        bodyslices = emailsteak[0].split("\n")
        readslices = ['']
        readcursor = 0      # (Integer) Points the current cursor position
        recipients = 0      # (Integer) The number of 'Final-Recipient' header
        v = nil

        while e = bodyslices.shift do
          # Read error messages and delivery status lines from the head of the email
          # to the previous line of the beginning of the original message.
          readslices << e # Save the current line for the next loop

          if readcursor == 0
            # Beginning of the bounce message or message/delivery-status part
            readcursor |= Indicators[:deliverystatus] if e == StartingOf[:message][0]
            next
          end
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
                  dscontents << Sisimai::Lhost.DELIVERYSTATUS
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
              next unless fieldtable[o[0]]
              v[fieldtable[o[0]]] = o[2]

              next unless f == 1
              permessage[fieldtable[o[0]]] = o[2]
            end
          else
            # Continued line of the value of Diagnostic-Code field
            next unless readslices[-2].start_with?('Diagnostic-Code:')
            next unless cv = e.match(/\A[ \t]+(.+)\z/)
            v['diagnosis'] << ' ' << cv[1]
            readslices[-1] = 'Diagnostic-Code: ' << e
          end
        end
        return nil unless recipients > 0

        dscontents.each do |e|
          # Set default values if each value is empty.
          e['lhost'] ||= permessage['rhost']
          permessage.each_key { |a| e[a] ||= permessage[a] || '' }
          e['diagnosis'] = Sisimai::String.sweep(e['diagnosis'].tr("\n", ' '))

          if e['status'].to_s.start_with?('5.0.0', '5.1.0', '4.0.0', '4.1.0')
            # Get other D.S.N. value from the error message
            errormessage = e['diagnosis']

            if cv = e['diagnosis'].match(/["'](\d[.]\d[.]\d.+)['"]/)
              # 5.1.0 - Unknown address error 550-'5.7.1 ...
              errormessage = cv[1]
            end
            e['status'] = Sisimai::SMTP::Status.find(errormessage) || e['status']
          end

          MessagesOf.each_key do |r|
            # Verify each regular expression of session errors
            next unless MessagesOf[r].any? { |a| e['diagnosis'].include?(a) }
            e['reason'] = r
            break
          end
          e['reason'] ||= Sisimai::SMTP::Status.name(e['status']) || ''
        end

        return { 'ds' => dscontents, 'rfc822' => emailsteak[1] }
      end
      def description; return 'Amazon SES(Receiving): https://aws.amazon.com/ses/'; end
    end
  end
end
