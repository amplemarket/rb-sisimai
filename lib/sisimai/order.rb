module Sisimai
  # Sisimai::Order - Parent class for making optimized order list for calling
  # MTA modules
  module Order
    # Imported from p5-Sisimail/lib/Sisimai/Order.pm
    class << self
      require 'sisimai/lhost'

      # There are another patterns in the value of "Subject:" header of a bounce
      # mail generated by the following MTA/ESP modules
      OrderE0 = [
        'Sisimai::Lhost::MailRu',
        'Sisimai::Lhost::Yandex',
        'Sisimai::Lhost::Exim',
        'Sisimai::Lhost::Sendmail',
        'Sisimai::Lhost::Aol',
        'Sisimai::Lhost::Office365',
        'Sisimai::Lhost::Exchange2007',
        'Sisimai::Lhost::Exchange2003',
        'Sisimai::Lhost::AmazonWorkMail',
        'Sisimai::Lhost::AmazonSES',
        'Sisimai::Lhost::InterScanMSS',
        'Sisimai::Lhost::KDDI',
        'Sisimai::Lhost::SurfControl',
        'Sisimai::Lhost::Verizon',
        'Sisimai::Lhost::ApacheJames',
        'Sisimai::Lhost::X2',
        'Sisimai::Lhost::X5',
        'Sisimai::Lhost::FML',
      ].freeze

      # Fallback list: The following MTA/ESP modules is not listed OrderE0
      OrderE1 = [
        'Sisimai::Lhost::Postfix',
        'Sisimai::Lhost::GSuite',
        'Sisimai::Lhost::Yahoo',
        'Sisimai::Lhost::Outlook',
        'Sisimai::Lhost::GMX',
        'Sisimai::Lhost::MessagingServer',
        'Sisimai::Lhost::EinsUndEins',
        'Sisimai::Lhost::Domino',
        'Sisimai::Lhost::Notes',
        'Sisimai::Lhost::Qmail',
        'Sisimai::Lhost::Courier',
        'Sisimai::Lhost::OpenSMTPD',
        'Sisimai::Lhost::Zoho',
        'Sisimai::Lhost::MessageLabs',
        'Sisimai::Lhost::MXLogic',
        'Sisimai::Lhost::MailFoundry',
        'Sisimai::Lhost::McAfee',
        'Sisimai::Lhost::V5sendmail',
        'Sisimai::Lhost::MFILTER',
        'Sisimai::Lhost::SendGrid',
        'Sisimai::Lhost::ReceivingSES',
        'Sisimai::Lhost::Amavis',
        'Sisimai::Lhost::Google',
        'Sisimai::Lhost::EZweb',
        'Sisimai::Lhost::IMailServer',
        'Sisimai::Lhost::MailMarshalSMTP',
        'Sisimai::Lhost::Activehunter',
        'Sisimai::Lhost::Bigfoot',
        'Sisimai::Lhost::Biglobe',
        'Sisimai::Lhost::Facebook',
        'Sisimai::Lhost::X4',
        'Sisimai::Lhost::X1',
        'Sisimai::Lhost::X3',
      ].freeze

      # The following order is decided by the first 2 words of Subject: header
      Subject = {
        'abuse-report'     => ['Sisimai::ARF'],
        'auto'             => ['Sisimai::RFC3834'],
        'auto-reply'       => ['Sisimai::RFC3834'],
        'automatic-reply'  => ['Sisimai::RFC3834'],
        'aws-notification' => ['Sisimai::Lhost::AmazonSES'],
        'complaint-about'  => ['Sisimai::ARF'],
        'delivery-failure' => ['Sisimai::Lhost::Domino', 'Sisimai::Lhost::X2'],
        'delivery-notification' => ['Sisimai::Lhost::MessagingServer'],
        'delivery-status'  => [
          'Sisimai::Lhost::GSuite',
          'Sisimai::Lhost::Google',
          'Sisimai::Lhost::Outlook',
          'Sisimai::Lhost::McAfee',
          'Sisimai::Lhost::OpenSMTPD',
          'Sisimai::Lhost::AmazonSES',
          'Sisimai::Lhost::AmazonWorkMail',
          'Sisimai::Lhost::ReceivingSES',
          'Sisimai::Lhost::X3',
        ],
        'dmarc-ietf-dmarc' => ['Sisimai::ARF'],
        'email-feedback'   => ['Sisimai::ARF'],
        'failed-delivery'  => ['Sisimai::Lhost::X2'],
        'failure-delivery' => ['Sisimai::Lhost::X2'],
        'failure-notice'   => [
          'Sisimai::Lhost::Yahoo',
          'Sisimai::Lhost::Qmail',
          'Sisimai::Lhost::MFILTER',
          'Sisimai::Lhost::Activehunter',
          'Sisimai::Lhost::X4',
        ],
        'loop-alert' => ['Sisimai::Lhost::FML'],
        'non-remis'  => ['Sisimai::Lhost::Exchange2007'],
        'notice'     => ['Sisimai::Lhost::Courier'],
        'mail-delivery' => [
          'Sisimai::Lhost::Exim',
          'Sisimai::Lhost::MailRu',
          'Sisimai::Lhost::GMX',
          'Sisimai::Lhost::EinsUndEins',
          'Sisimai::Lhost::Zoho',
          'Sisimai::Lhost::MessageLabs',
          'Sisimai::Lhost::MXLogic',
        ],
        'mail-failure' => ['Sisimai::Lhost::Exim'],
        'mail-not'     => ['Sisimai::Lhost::X4'],
        'mail-system'  => ['Sisimai::Lhost::EZweb'],
        'message-delivery'   => ['Sisimai::Lhost::MailFoundry'],
        'message-frozen'     => ['Sisimai::Lhost::Exim'],
        'permanent-delivery' => ['Sisimai::Lhost::X4'],
        'postmaster-notify'  => ['Sisimai::Lhost::Sendmail'],
        'returned-mail' => [
          'Sisimai::Lhost::Sendmail',
          'Sisimai::Lhost::Aol',
          'Sisimai::Lhost::V5sendmail',
          'Sisimai::Lhost::Bigfoot',
          'Sisimai::Lhost::Biglobe',
          'Sisimai::Lhost::X1',
        ],
        'sorry-your' => ['Sisimai::Lhost::Facebook'],
        'undeliverable-mail' => [
          'Sisimai::Lhost::Amavis',
          'Sisimai::Lhost::MailMarshalSMTP',
          'Sisimai::Lhost::IMailServer',
        ],
        'undeliverable' => [
          'Sisimai::Lhost::Office365',
          'Sisimai::Lhost::Exchange2007',
          'Sisimai::Lhost::Aol',
          'Sisimai::Lhost::Exchange2003',
        ],
        'undeliverable-message' => ['Sisimai::Lhost::Notes', 'Sisimai::Lhost::Verizon'],
        'undelivered-mail' => [
          'Sisimai::Lhost::Postfix',
          'Sisimai::Lhost::Aol',
          'Sisimai::Lhost::SendGrid',
          'Sisimai::Lhost::Zoho',
        ],
        'warning' => ['Sisimai::Lhost::Sendmail', 'Sisimai::Lhost::Exim'],
      }.freeze

      # @abstract Returns an MTA Order decided by the first word of the "Subject": header
      # @param    [String] argv0 Subject header string
      # @return   [Array]        Order of MTA modules
      # @since    v4.25.4
      def make(argv0 = '')
        return [] if argv0.empty?
        argv0 = argv0.downcase.tr('_[] ', ' ').squeeze(' ').sub(/\A[ ]+/, '')
        words = argv0.split(/[ ]/, 3)

        if words[0].include?(':')
          # Undeliverable: ..., notify: ...
          first = argv0.split(':').shift
        else
          # Postmaster notify, returned mail, ...
          first = words.slice(0, 2).join('-')
        end
        first.delete!(':",*')
        return Subject[first] || []
      end

      # @abstract Make default order of MTA modules to be loaded
      # @return   [Array] Default order list of MTA modules
      def default; return Sisimai::Lhost.index.map { |e| 'Sisimai::Lhost::' << e }; end

      # @abstract Make MTA module list as a spare
      # @return   [Array] Ordered module list
      def another; return [OrderE0, OrderE1].flatten; end
    end
  end
end
