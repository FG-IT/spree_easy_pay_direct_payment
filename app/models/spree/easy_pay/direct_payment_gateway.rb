require 'activemerchant'
require 'nokogiri'

module Spree
  module EasyPay
    class DirectPaymentGateway < ActiveMerchant::Billing::AuthorizeNetGateway
      self.test_url = 'https://secure.easypaydirectgateway.com/api/transrequest.php'
      self.live_url = 'https://secure.easypaydirectgateway.com/api/transrequest.php'

      def initialize(options = {})
        self.test_url = options[:test_url]
        self.live_url = options[:live_url]
        super
      end

      def add_credit_card(xml, credit_card, action)
        if credit_card.track_data
          add_swipe_data(xml, credit_card)
        else
          xml.payment do
            xml.creditCard do
              xml.cardNumber(truncate(credit_card.number, 16))
              xml.expirationDate(format(credit_card.year, :four_digits) + '-' + format(credit_card.month, :two_digits))
              xml.cardCode(credit_card.verification_value) if credit_card.valid_card_verification_value?(credit_card.verification_value, credit_card.brand)
              xml.cryptogram(credit_card.payment_cryptogram) if credit_card.is_a?(ActiveMerchant::Billing::NetworkTokenizationCreditCard) && action != :credit
            end
          end
        end
      end


      def parse_normal(action, body)
        doc = Nokogiri::XML(body)
        doc.remove_namespaces!

        response = {action: action}

        response[:response_code] = if (element = doc.at_xpath('//transactionResponse/responseCode'))
                                     empty?(element.content) ? nil : element.content.to_i
                                   end

        if (element = doc.at_xpath('//errors/error'))
          response[:response_reason_code] = element.at_xpath('errorCode').content[/0*(\d+)$/, 1]
          response[:response_reason_text] = element.at_xpath('errorText').content.chomp('.')
        elsif (element = doc.at_xpath('//transactionResponse/messages/message'))
          response[:response_reason_code] = element.at_xpath('code').content[/0*(\d+)$/, 1]
          begin
            response[:response_reason_text] = element.at_xpath('description').content.chomp('.')
          rescue
            response[:response_reason_text] = element.at_xpath('text').content.chomp('.')
          end
        elsif (element = doc.at_xpath('//messages/message'))
          response[:response_reason_code] = element.at_xpath('code').content[/0*(\d+)$/, 1]
          response[:response_reason_text] = element.at_xpath('text').content.chomp('.')
        else
          response[:response_reason_code] = nil
          response[:response_reason_text] = ''
        end

        response[:avs_result_code] =
            if (element = doc.at_xpath('//avsResultCode'))
              empty?(element.content) ? nil : element.content
            end

        response[:transaction_id] =
            if element = doc.at_xpath('//transId')
              empty?(element.content) ? nil : element.content
            end

        response[:card_code] =
            if element = doc.at_xpath('//cvvResultCode')
              empty?(element.content) ? nil : element.content
            end

        response[:authorization_code] =
            if element = doc.at_xpath('//authCode')
              empty?(element.content) ? nil : element.content
            end

        response[:cardholder_authentication_code] =
            if element = doc.at_xpath('//cavvResultCode')
              empty?(element.content) ? nil : element.content
            end

        response[:account_number] =
            if element = doc.at_xpath('//accountNumber')
              empty?(element.content) ? nil : element.content[-4..-1]
            end

        response[:test_request] =
            if element = doc.at_xpath('//testRequest')
              empty?(element.content) ? nil : element.content
            end

        response[:full_response_code] =
            if element = doc.at_xpath('//messages/message/code')
              empty?(element.content) ? nil : element.content
            end

        response
      end


    end
  end
end

