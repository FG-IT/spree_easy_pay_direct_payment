module Spree
  class Gateway::EasyPayDirectPayment < Gateway
    preference :login, :string
    preference :password, :string
    preference :server, :string, default: "test"
    preference :test_url, :string, default: "https://secure.easypaydirectgateway.com/api/transrequest.php"
    preference :live_url, :string, default: "https://secure.easypaydirectgateway.com/api/transrequest.php"

    def provider_class
      Spree::EasyPay::DirectPaymentGateway
    end

    def options
      if !['live','test'].include?(self.preferred_server)
        raise "You must set the 'server' preference in your payment method (Gateway::AuthorizeNet) to either 'live' or 'test'"
      end
      super().merge(test: (self.preferred_server != "live"))
    end


    def purchase(money_in_cents, source, gateway_options)
      #check for test orders
      if self.preferred_server=='live' && test_card(source)
        Class.new do
          def success?; false; end
          def message; 'Credit card is invalid, please try another one.'; end
          def to_s
             "#{message}"
          end
        end.new
      else
        provider
        response = provider.purchase(money_in_cents, source, gateway_options)
        response
      end
    end

    def authorize(money_in_cents, source, gateway_options)
      #check for test orders
      if self.preferred_server=='live' && test_card(source)
        Class.new do
          def success?; false; end
          def message; 'Credit card is invalid, please try another one.'; end
          def to_s
            "#{message}"
          end
        end.new
      else
        provider
        response = provider.authorize(money_in_cents, source, gateway_options)
        response
      end
    end

    def cancel(response_code)
      provider
      # From: http://community.developer.authorize.net/t5/The-Authorize-Net-Developer-Blog/Refunds-in-Retail-A-user-friendly-approach-using-AIM/ba-p/9848
      # DD: if unsettled, void needed
      response = provider.void(response_code)
      # DD: if settled, credit/refund needed (CAN'T DO WITHOUT CREDIT CARD ON AUTH.NET)
      #response = provider.refund(response_code) unless response.success?

      response
    end

    def credit(amount, response_code, refund, gateway_options = {})
      gateway_options[:card_number] = refund[:originator].payment.source.last_digits
      provider
      provider.refund(amount, response_code, gateway_options)
    end

    private

    def test_card(credit_card)
        test_numbers = %w{
                      378282246310005 371449635398431 378734493671000
                      2223000048400011 2223520043560014 5555555555554444
                      4111111111111111 4012888888881881 4222222222222
                      4005519200000004 4009348888881881 4012000033330026
                      4012000077777777 4217651111111119 4500600000000061
                      4000111111111115 5454545454545454 5105105105105100
                      }
        test_numbers.include?(credit_card.number)
    end
    def auth_net_gateway
      @_auth_net_gateway ||= begin
        ActiveMerchant::Billing::Base.gateway_mode = preferred_server.to_sym
        gateway_options = options
        gateway_options[:test_requests] = false # DD: never ever do test requests because just returns transaction_id = 0
        gateway_options[:test_url] = preferred_test_url.to_sym
        gateway_options[:live_url] = preferred_live_url.to_sym
        provider_class.new(gateway_options)
      end
    end
  end
end
