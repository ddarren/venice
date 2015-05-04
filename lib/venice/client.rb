require 'json'
require 'net/https'
require 'uri'

module Venice
  ITUNES_PRODUCTION_RECEIPT_VERIFICATION_ENDPOINT = "https://buy.itunes.apple.com/verifyReceipt"
  ITUNES_DEVELOPMENT_RECEIPT_VERIFICATION_ENDPOINT = "https://sandbox.itunes.apple.com/verifyReceipt"

  class Client
    attr_accessor :verification_url
    attr_writer :shared_secret

    class << self
      def development
        client = self.new
        client.verification_url = ITUNES_DEVELOPMENT_RECEIPT_VERIFICATION_ENDPOINT
        client
      end

      def production
        client = self.new
        client.verification_url = ITUNES_PRODUCTION_RECEIPT_VERIFICATION_ENDPOINT
        client
      end
    end

    def initialize(seconds_till_timeout=5)
      @seconds_till_timeout = seconds_till_timeout
      @verification_url = ENV['IAP_VERIFICATION_ENDPOINT']
    end

    def verify!(data, options = {})
      json = json_response_from_verifying_data(data)
      status = json['status'].to_i

      case status
      when 0, 21006
        receipts = []
        json['receipt']['in_app'].each do |transaction|
          receipt_attributes = json['receipt']['in_app'].first
          receipts.push Receipt.new(receipt_attributes)     
        end

        return receipts
      else
        raise Receipt::VerificationError.new(status)
      end
    end

    private

    def json_response_from_verifying_data(data)
      parameters = {
        'receipt-data' => data
      }

      parameters['password'] = @shared_secret if @shared_secret

      uri = URI(@verification_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = @seconds_till_timeout
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Accept'] = "application/json"
      request['Content-Type'] = "application/json"
      request.body = parameters.to_json

      response = http.request(request)

      JSON.parse(response.body)
    end
  end
end
