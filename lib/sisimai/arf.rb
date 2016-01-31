module Sisimai
  # Sisimai::ARF is a parser for email returned as a FeedBack Loop report message.
  module ARF
    # Imported from p5-Sisimail/lib/Sisimai/Message.pm
    class << self
      require 'sisimai/mta'
      require 'sisimai/rfc5322'

      Re0 =  {
        :'content-type' => %r|multipart/mixed|,
        :'report-type'  => %r/report-type=["]?feedback-report["]?/,
        :'from'         => %r{(?:
           staff[@]hotmail[.]com\z
          |complaints[@]email-abuse[.]amazonses[.]com\z
          )
        }x,
        :'subject'      => %r/complaint[ ]about[ ]message[ ]from[ ]/,
      }
      # http://tools.ietf.org/html/rfc5965
      # http://en.wikipedia.org/wiki/Feedback_loop_(email)
      # http://en.wikipedia.org/wiki/Abuse_Reporting_Format
      #
      # Netease DMARC uses:    This is a spf/dkim authentication-failure report for an email message received from IP
      # OpenDMARC 1.3.0 uses:  This is an authentication failure report for an email message received from IP
      # Abusix ARF uses        this is an autogenerated email abuse complaint regarding your network.
      Re1 = {
        :begin  => %r{\A(?>
           [Tt]his[ ]is[ ].+[ ]email[ ]abuse[ ]report
          |[Tt]his[ ]is[ ](?:
             an[ ]autogenerated[ ]email[ ]abuse[ ]complaint
            |an?[ ].+[ ]report[ ]for
            |a[ ].+[ ]authentication[ -]failure[ ]report[ ]for
            )
          )
        }x,
        :rfc822 => %r[\AContent-Type: (:?message/rfc822|text/rfc822-headers)],
        :endof  => %r/\A__END_OF_EMAIL_MESSAGE__\z/,
      }
      Indicators = Sisimai::MTA.INDICATORS
      LongFields = Sisimai::RFC5322.LONGFIELDS
      RFC822Head = Sisimai::RFC5322.HEADERFIELDS

      def description; return 'Abuse Feedback Reporting Format'; end
      def smtpagent;   return 'FeedBack-Loop'; end
      def headerlist;  return []; end
      def pattern;     return Re0; end

      # Email is a Feedback-Loop message or not
      # @param    [Hash] heads    Email header including "Content-Type", "From",
      #                           and "Subject" field
      # @return   [True,False]    true: Feedback Loop
      #                           false: is not Feedback loop
      def is_arf(heads)
        return false unless heads
        match = false

        if heads['content-type'] =~ Re0[:'report-type']
          # Content-Type: multipart/report; report-type=feedback-report; ...
          match = true

        elsif heads['content-type'] =~ Re0[:'content-type']
          # Microsoft (Hotmail, MSN, Live, Outlook) uses its own report format.
          # Amazon SES Complaints bounces
          if heads['from'] =~ Re0[:'from'] && heads['subject'] =~ Re0[:'subject']
            # From: staff@hotmail.com
            # From: complaints@email-abuse.amazonses.com
            # Subject: complaint about message from 192.0.2.1
            match = true
          end
        end
        return match
      end

      # Detect an error for Feedback Loop
      # @param         [Hash] mhead       Message header of a bounce email
      # @options mhead [String] from      From header
      # @options mhead [String] date      Date header
      # @options mhead [String] subject   Subject header
      # @options mhead [Array]  received  Received headers
      # @options mhead [String] others    Other required headers
      # @param         [String] mbody     Message body of a bounce email
      # @return        [Hash, Nil]        Bounce data list and message/rfc822 part
      #                                   or Undef if it failed to parse or the
      #                                   arguments are missing
      def scan(mhead, mbody)
        return nil unless self.is_arf(mhead)

        require 'sisimai/address'
        dscontents = []; dscontents << Sisimai::MTA.DELIVERYSTATUS
        hasdivided = mbody.split("\n")
        havepassed = ['']
        rfc822next = { 'from' => false, 'to' => false, 'subject' => false }
        rfc822part = ''   # (String) message/rfc822-headers part
        previousfn = ''   # (String) Previous field name
        readcursor = 0    # (Integer) Points the current cursor position
        recipients = 0    # (Integer) The number of 'Final-Recipient' header
        rcptintext = ''   # (String) Recipient address in the message body
        commondata = {
          'diagnosis' => '',  # Error message
          'from'      => '',  # Original-Mail-From:
          'rhost'     => '',  # Reporting-MTA:
        }
        arfheaders = {
          'feedbacktype' => nil,   # FeedBack-Type:
          'rhost'        => nil,   # Source-IP:
          'agent'        => nil,   # User-Agent:
          'date'         => nil,   # Arrival-Date:
          'authres'      => nil,   # Authentication-Results:
        }
        v = nil

        # 3.1.  Required Fields
        #
        #   The following report header fields MUST appear exactly once:
        #
        #   o  "Feedback-Type" contains the type of feedback report (as defined
        #      in the corresponding IANA registry and later in this memo).  This
        #      is intended to let report parsers distinguish among different
        #      types of reports.
        #
        #   o  "User-Agent" indicates the name and version of the software
        #      program that generated the report.  The format of this field MUST
        #      follow section 14.43 of [HTTP].  This field is for documentation
        #      only; there is no registry of user agent names or versions, and
        #      report receivers SHOULD NOT expect user agent names to belong to a
        #      known set.
        #
        #   o  "Version" indicates the version of specification that the report
        #      generator is using to generate the report.  The version number in
        #      this specification is set to "1".
        #
        hasdivided.each do |e|
          # Save the current line for the next loop
          havepassed << e; p = havepassed[-2]

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
            if cv = e.match(/X-HmXmrOriginalRecipient:[ ]*(.+)\z/)
              # Microsoft ARF: original recipient.
              dscontents[-1]['recipient'] = Sisimai::Address.s3s4(cv[1])
              recipients += 1

              # The "X-HmXmrOriginalRecipient" header appears only once so
              # we take this opportunity to hard-code ARF headers missing in
              # Microsoft's implementation.
              arfheaders['feedbacktype'] = 'abuse'
              arfheaders['agent'] = 'Microsoft Junk Mail Reporting Program'

            elsif cv = e.match(/\AFrom:[ ]*(.+)\z/)
              # Microsoft ARF: original sender.
              if commondata['from'].size == 0
                commondata['from'] = Sisimai::Address.s3s4(cv[1])
              end

            elsif cv = e.match(/\A([-0-9A-Za-z]+?)[:][ ]*(.+)\z/)
              # Get required headers only
              lhs = cv[1].downcase
              rhs = cv[2]

              previousfn = ''
              next unless RFC822Head.key?(lhs)

              previousfn  = lhs
              rfc822part += e + "\n"
              rcptintext  = rhs if lhs == 'to'

            elsif e =~ /\A[ \t]+/
              # Continued line from the previous line
              rfc822part += e + "\n" if LongFields.key?(previousfn)
              next if e.size > 0
              rcptintext += e if previousfn == 'to'
            end

          else
            # Before "message/rfc822"
            next unless readcursor & Indicators[:'deliverystatus'] > 0
            next unless e.size > 0

            # Feedback-Type: abuse
            # User-Agent: SomeGenerator/1.0
            # Version: 0.1
            # Original-Mail-From: <somespammer@example.net>
            # Original-Rcpt-To: <kijitora@example.jp>
            # Received-Date: Thu, 29 Apr 2009 00:00:00 JST
            # Source-IP: 192.0.2.1
            v = dscontents[-1]

            if cv = e.match(/\AOriginal-Rcpt-To:[ ]+[<]?(.+)[>]?\z/) ||
               cv = e.match(/\ARedacted-Address:[ ]([^ ].+[@])\z/)
              # Original-Rcpt-To header field is optional and may appear any
              # number of times as appropriate:
              # Original-Rcpt-To: <user@example.com>
              # Redacted-Address: localpart@
              if v['recipient']
                # There are multiple recipient addresses in the message body.
                dscontents << Sisimai::MTA.DELIVERYSTATUS
                  v = dscontents[-1]
              end
              v['recipient'] = Sisimai::Address.s3s4(cv[1])
              recipients += 1

            elsif cv = e.match(/\AFeedback-Type:[ ]*([^ ]+)\z/)
              # The header field MUST appear exactly once.
              # Feedback-Type: abuse
              arfheaders['feedbacktype'] = cv[1]

            elsif cv = e.match(/\AAuthentication-Results:[ ]*(.+)\z/)
              # "Authentication-Results" indicates the result of one or more
              # authentication checks run by the report generator.
              #
              # Authentication-Results: mail.example.com;
              #   spf=fail smtp.mail=somespammer@example.com
              arfheaders['authres'] = cv[1]

            elsif cv = e.match(/\AUser-Agent:[ ]*(.+)\z/)
              # The header field MUST appear exactly once.
              # User-Agent: SomeGenerator/1.0
              arfheaders['agent'] = cv[1]

            elsif cv = e.match(/\A(?:Received|Arrival)-Date:[ ]*(.+)\z/)
              # Arrival-Date header is optional and MUST NOT appear more than
              # once.
              # Received-Date: Thu, 29 Apr 2010 00:00:00 JST
              # Arrival-Date: Thu, 29 Apr 2010 00:00:00 +0000
              arfheaders['date'] = cv[1]

            elsif cv = e.match(/\AReporting-MTA:[ ]*dns;[ ]*(.+)\z/)
              # The header is optional and MUST NOT appear more than once.
              # Reporting-MTA: dns; mx.example.jp
              commondata['rhost'] = cv[1]

            elsif cv = e.match(/\ASource-IP:[ ]*(.+)\z/)
              # The header is optional and MUST NOT appear more than once.
              # Source-IP: 192.0.2.45
              arfheaders['rhost'] = cv[1]

            elsif cv = e.match(/\AOriginal-Mail-From:[ ]*(.+)\z/)
              # the header is optional and MUST NOT appear more than once.
              # Original-Mail-From: <somespammer@example.net>
              if commondata['from'].empty?
                commondata['from'] = Sisimai::Address.s3s4(cv[1])
              end

            elsif e =~ Re1[:begin]
              # This is an email abuse report for an email message with the
              #   message-id of 0000-000000000000000000000000000000000@mx
              #   received from IP address 192.0.2.1 on
              #   Thu, 29 Apr 2010 00:00:00 +0900 (JST)
              commondata['diagnosis'] = e
            end
          end
        end

        if arfheaders['feedbacktype'] == 'auth-failure' && arfheaders['authres']
          # Append the value of Authentication-Results header
          commondata['diagnosis'] += ' ' + arfheaders['authres']
        end

        if recipients == 0
          # Insert pseudo recipient address when there is no valid recipient
          # address in the message.
          dscontents[-1]['recipient'] = Sisimai::Address.undisclosed('r')
          recipients = 1
        end

        unless rfc822part =~ /\bFrom: [^ ]+[@][^ ]+\b/
          # There is no "From:" header in the original message
          if commondata['from'].size > 0
            # Append the value of "Original-Mail-From" value as a sender address.
            rfc822part += sprintf("From: %s\n", commondata['from'])
          end
        end

        if cv = mhead['subject'].match(/complaint about message from (\d{1,3}[.]\d{1,3}[.]\d{1,3}[.]\d{1,3})/)
          # Microsoft ARF: remote host address.
          arfheaders['rhost'] = cv[1]
          commondata['diagnosis'] = sprintf(
            'This is a Microsoft email abuse report for an email message received from IP %s on %s',
            arfheaders['rhost'], mhead['date'])
        end

        dscontents.map do |e|
          if e['recipient'] =~ /\A[^ ]+[@]\z/
            # AOL = http://forums.cpanel.net/f43/aol-brutal-work-71473.html
            e['recipient'] = Sisimai::Address.s3s4(rcptintext)
          end
          arfheaders.each_key { |a| e[a] ||= arfheaders[a] || '' }
          e.delete('authres')

          e['softbounce'] = -1
          e['diagnosis']  = commondata['diagnosis'] unless e['diagnosis']
          e['date']       = mhead['date'] if e['date'].empty?

          if e['rhost'].empty?
            # Get the remote IP address from the message body
            if commondata['rhost'].size > 0
              # The value of "Reporting-MTA" header
              e['rhost'] = commondata['rhost']

            elsif cv = e['diagnosis'].match(/\breceived from IP address ([^ ]+)/)
              # This is an email abuse report for an email message received
              # from IP address 24.64.1.1 on Thu, 29 Apr 2010 00:00:00 +0000
              e['rhost'] = cv[1]
            end
          end

          if mhead['received'].size > 0
            # Get localhost and remote host name from Received header.
            r0 = mhead['received']
            ['lhost', 'rhost'].each { |a| e[a] ||= '' }
            e['lhost'] = Sisimai::RFC5322.received(r0[0]).shift if e['lhost'].empty?
            e['rhost'] = Sisimai::RFC5322.received(r0[-1]).pop  if e['rhost'].empty?
          end

          e['spec']    = 'SMTP'
          e['action']  = 'failed'
          e['reason']  = 'feedback'
          e['command'] = ''
          e['status']  = ''
          e['alias']   = ''
          e['agent']   = self.smtpagent if e['agent'].empty?
        end
        return { 'ds' => dscontents, 'rfc822' => rfc822part }
      end
    end
  end
end
