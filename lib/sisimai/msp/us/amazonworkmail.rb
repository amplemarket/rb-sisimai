module Sisimai
  module MSP::US
    # Sisimai::MSP::US::AmazonWorkMail parses a bounce email which created by
    # Amazon WorkMail. Methods in the module are called from only Sisimai::Message.
    module AmazonWorkMail
      # Imported from p5-Sisimail/lib/Sisimai/MSP/US/AmazonWorkMail.pm
      class << self
        require 'sisimai/msp'
        require 'sisimai/rfc5322'

        # https://aws.amazon.com/workmail/
        Re0 = {
          :'subject'  => %r/Delivery[_ ]Status[_ ]Notification[_ ].+Failure/,
          :'received' => %r/.+[.]smtp-out[.].+[.]amazonses[.]com\b/,
          :'x-mailer' => %r/\AAmazon WorkMail\z/,
        }
        Re1 = {
          :begin  => %r/\ATechnical report:\z/,
          :rfc822 => %r|\Acontent-type: message/rfc822\z|,
          :endof  => %r/\A__END_OF_EMAIL_MESSAGE__\z/,
        }
        Indicators = Sisimai::MSP.INDICATORS
        LongFields = Sisimai::RFC5322.LONGFIELDS
        RFC822Head = Sisimai::RFC5322.HEADERFIELDS

        def description; return 'Amazon WorkMail: https://aws.amazon.com/workmail/'; end
        def smtpagent;   return 'US::AmazonWorkMail'; end

        # X-Mailer: Amazon WorkMail
        # X-Original-Mailer: Amazon WorkMail
        # X-Ses-Outgoing: 2016.01.14-54.240.27.159
        def headerlist;  return ['X-SES-Outgoing', 'X-Original-Mailer']; end
        def pattern;     return Re0; end

        # Parse bounce messages from Amazon WorkMail
        # @param         [Hash] mhead       Message header of a bounce email
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
          return nil unless mhead
          return nil unless mbody

          match = 0
          xmail = mhead['x-original-mailer'] || mhead['x-mailer'] || ''

          match += 1 if mhead['x-ses-outgoing']
          unless xmail.empty?
            # X-Mailer: Amazon WorkMail
            # X-Original-Mailer: Amazon WorkMail
            match += 1 if xmail =~ Re0[:'x-mailer']
          end
          return nil if match < 2

          if mbody =~ /^Content-Transfer-Encoding: quoted-printable$/
            # This is a multi-part message in MIME format. Your mail reader does not
            # understand MIME message format.
            # --=_gy7C4Gpes0RP4V5Bs9cK4o2Us2ZT57b-3OLnRN+4klS8dTmQ
            # Content-Type: text/plain; charset=iso-8859-15
            # Content-Transfer-Encoding: quoted-printable
            require 'sisimai/mime'
            mbody = mbody.sub(/\A.+?quoted-printable/ms, '')
            mbody = Sisimai::MIME.qprintd(mbody)
          end

          dscontents = []; dscontents << Sisimai::MSP.DELIVERYSTATUS
          hasdivided = mbody.split("\n")
          rfc822next = { 'from' => false, 'to' => false, 'subject' => false }
          rfc822part = ''     # (String) message/rfc822-headers part
          previousfn = ''     # (String) Previous field name
          readcursor = 0      # (Integer) Points the current cursor position
          recipients = 0      # (Integer) The number of 'Final-Recipient' header
          connvalues = 0      # (Integer) Flag, 1 if all the value of $connheader have been set
          connheader = {
            'lhost' => '',    # The value of Reporting-MTA header
          }
          v = nil

          hasdivided.each do |e|
            if readcursor == 0
              # Beginning of the bounce message or delivery status part
              if e =~ Re1[:begin]
                readcursor |= Indicators[:'deliverystatus']
                next
              end
            end

            if readcursor & Indicators[:'message-rfc822'] == 0
              # Beginning of the original message part
              if e =~ Re1[:rfc822]
                readcursor |= Indicators[:'message-rfc822']
                next
              end
            end

            if readcursor & Indicators[:'message-rfc822'] > 0
              # After "message/rfc822"
              if cv = e.match(/\A([-0-9A-Za-z]+?)[:][ ]*.+\z/)
                # Get required headers only
                lhs = cv[1].downcase
                previousfn = ''
                next unless RFC822Head.key?(lhs)

                previousfn  = lhs
                rfc822part += e + "\n"

              elsif e =~ /\A[ \t]+/
                # Continued line from the previous line
                next if rfc822next[previousfn]
                rfc822part += e + "\n" if LongFields.key?(previousfn)

              else
                # Check the end of headers in rfc822 part
                next unless LongFields.key?(previousfn)
                next unless e.empty?
                rfc822next[previousfn] = true
              end

            else
              # Before "message/rfc822"
              next if readcursor & Indicators[:'deliverystatus'] == 0
              next if e.empty?

              if connvalues == connheader.keys.size
                # Action: failed
                # Final-Recipient: rfc822; kijitora@libsisimai.org
                # Diagnostic-Code: smtp; 554 4.4.7 Message expired: unable to deliver in 840 minutes.<421 4.4.2 Connection timed out>
                # Status: 4.4.7
                v = dscontents[-1]

                if cv = e.match(/\A[Ff]inal-[Rr]ecipient:[ ]*(?:RFC|rfc)822;[ ]*([^ ]+)\z/)
                  # Final-Recipient: RFC822; kijitora@example.jp
                  if v['recipient']
                    # There are multiple recipient addresses in the message body.
                    dscontents << Sisimai::MSP.DELIVERYSTATUS
                    v = dscontents[-1]
                  end
                  v['recipient'] = cv[1]
                  recipients += 1

                elsif cv = e.match(/\A[Aa]ction:[ ]*(.+)\z/)
                  # Action: failed
                  v['action'] = cv[1].downcase

                elsif cv = e.match(/\A[Ss]tatus:[ ]*(\d[.]\d+[.]\d+)/)
                  # Status: 5.1.1
                  v['status'] = cv[1]

                else
                  if cv = e.match(/\A[Dd]iagnostic-[Cc]ode:[ ]*(.+?);[ ]*(.+)\z/)
                    # Diagnostic-Code: SMTP; 550 5.1.1 <kijitora@example.jp>... User Unknown
                    v['spec'] = cv[1].upcase
                    v['diagnosis'] = cv[2]
                  end
                end
              else
                # Technical report:
                #
                # Reporting-MTA: dsn; a27-85.smtp-out.us-west-2.amazonses.com
                #
                if cv = e.match(/\A[Rr]eporting-MTA:[ ]*[DNSdns]+;[ ]*(.+)\z/)
                  # Reporting-MTA: dns; mx.example.jp
                  next if connheader['lhost'].size > 0
                  connheader['lhost'] = cv[1].downcase
                  connvalues += 1
                end
              end

              # <!DOCTYPE HTML><html>
              # <head>
              # <meta name="Generator" content="Amazon WorkMail v3.0-2023.77">
              # <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
              break if e =~ /\A[<]!DOCTYPE HTML[>][<]html[>]\z/
            end
          end

          return nil if recipients == 0
          require 'sisimai/string'
          require 'sisimai/smtp/status'

          dscontents.map do |e|
            # Set default values if each value is empty.
            connheader.each_key { |a| e[a] ||= connheader[a] || '' }

            if mhead['received'].size > 0
              # Get localhost and remote host name from Received header.
              r0 = mhead['received']
              %w|lhost rhost|.each { |a| e[a] ||= '' }
              e['lhost'] = Sisimai::RFC5322.received(r0[0]).shift if e['lhost'].empty?
              e['rhost'] = Sisimai::RFC5322.received(r0[-1]).pop  if e['rhost'].empty?
            end
            e['diagnosis'] = Sisimai::String.sweep(e['diagnosis'])

            if e['status'] =~ /\A[45][.][01][.]0\z/
              # Get other D.S.N. value from the error message
              errormessage = e['diagnosis']

              if cv = e['diagnosis'].match(/["'](\d[.]\d[.]\d.+)['"]/)
                # 5.1.0 - Unknown address error 550-'5.7.1 ...
                errormessage = cv[1]
              end
              pseudostatus = Sisimai::SMTP::Status.find(errormessage)
              e['status'] = pseudostatus if pseudostatus.size > 0
            end

            e['reason'] ||= Sisimai::SMTP::Status.name(e['status'])
            e['spec']   ||= 'SMTP'
            e['agent']    = Sisimai::MSP::US::AmazonWorkMail.smtpagent
          end

          return { 'ds' => dscontents, 'rfc822' => rfc822part }
        end

      end
    end
  end
end

