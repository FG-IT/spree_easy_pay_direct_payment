module SpreeEasyPayDirectPayment
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_easy_pay_direct_payment'

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    # initializer 'spree_easy_pay_direct_payment.environment', before: :load_config_initializers do |_app|
      # SpreeEasyPayDirectPayment::Config = SpreeEasyPayDirectPayment::Configuration.new
    # end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)

    initializer "spree.easypay_direct_payment.payment_methods", :after => "spree.register.payment_methods" do |app|
      app.config.spree.payment_methods << Spree::Gateway::EasyPayDirectPayment
    end
  end
end
