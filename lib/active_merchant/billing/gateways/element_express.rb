require 'rexml/document'



module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
  
    class ElementExpressGateway < Gateway
      self.test_url = 'https://certtransaction.elementexpress.com'
      self.live_url = 'https://transaction.elementexpress.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.elementps.com/'
      self.display_name = 'Element Payment Services'

      self.money_format = :dollars

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, 
          :account_id,
          :account_token,
          :application_id,
          :application_name,
          :acceptor_id
        )

        super
      end

      def new_transaction
        

        #<
        #<Transaction><TransactionAmount></TransactionAmount></Transaction>
      end

      DEFAULT_TERMINAL = "01"

      APPLICATION_VERSION = "1.0.0"


      INPUT_MAGSTRIPE = "2"
      INPUT_MANUAL = "4"

      TERMINAL_ENV_LOCAL_ATTENDED = "2"

      PARTIAL_NO_SUPPORT = "0"

      TICKET_MAX_LEN = 6

      def init_type(type)

        xml = REXML::Document.new

        xml.context[:attribute_quote] = :quote


        @type = type
        xml = xml.add_element(type)

        add_credentials(xml)

        xml.add_namespace("https://transaction.elementexpress.com")

        xml
      end

      def response_element
        @type + "Response"
      end

      def add_credentials(xml)
        x_app = xml.add_element("Application")


        x_app.add_element("ApplicationID").text = @options[:application_id]
        x_app.add_element("ApplicationName").text = @options[:application_name]
        x_app.add_element("ApplicationVersion").text = APPLICATION_VERSION

        x_cred = xml.add_element("Credentials")

        x_cred.add_element("AccountID").text = @options[:account_id]
        x_cred.add_element("AccountToken").text = @options[:account_token]
        x_cred.add_element("AcceptorID").text = @options[:acceptor_id]

      end

      def add_terminal(xml, input_code = INPUT_MANUAL)

        x_term = xml.add_element("Terminal")

        x_term.add_element("TerminalID").text = DEFAULT_TERMINAL
        x_term.add_element("CardPresentCode").text = 3 #not present

        x_term.add_element("CardholderPresentCode").text = 3 # not present

        x_term.add_element("CardInputCode").text = input_code

        x_term.add_element("CVVPresenceCode").text = 1 #not provided

        x_term.add_element("TerminalCapabilityCode").text = 5 #key entered

        x_term.add_element("TerminalEnvironmentCode").text = TERMINAL_ENV_LOCAL_ATTENDED

        x_term.add_element("MotoECICode").text = 2 #single

        x_term.add_element("TerminalType").text = 3 #MOTO

      end

      def add_transaction(xml,money=nil, transaction_id = nil)
        x_trans = xml.add_element("Transaction")

        x_trans.add_element("MarketCode").text = 2 #direct marketing

        x_trans.add_element("PartialApprovedFlag").text = PARTIAL_NO_SUPPORT

        if not transaction_id.nil?
          x_trans.add_element("TransactionID").text = transaction_id
        end

        if not money.nil?
          x_trans.add_element("TransactionAmount").text = amount(money)
        end

        x_trans
      end

      def credit(money,transaction_id, options ={})

        xml = init_type("CreditCardReturn")

        add_terminal(xml)

        x_trans = add_transaction(xml, money, transaction_id)

        add_invoice(x_trans, options)

        commit(xml)

      end

      def void(transaction_id, options = {})

        xml = init_type("CreditCardVoid")

        add_terminal(xml)

        x_trans = add_transaction(xml, nil, transaction_id)

        add_invoice(x_trans, options)

        commit(xml)

      end

      def purchase(money, payment, options={})

        xml = init_type("CreditCardSale")

        add_terminal(xml)

        x_trans = add_transaction(xml,money)
        
        add_invoice(x_trans, options)

        add_payment(xml, payment)

        add_address(xml, options)

        commit(xml)
      end

      def reversal(reversal, money, payment=nil, options={})

        xml = init_type("CreditCardReversal")

        add_terminal(xml)

        x_trans = add_transaction(xml,money,options[:transaction_id])

        x_trans.add_element("ReversalType").text = reversal
        
        add_invoice(x_trans, options)

        if payment
          add_payment(xml, payment)
        end

        commit(xml)

      end


      #def refund(money, authorization, options={})
      #  commit('refund', post)
      #end

      #def void(authorization, options={})
      #  commit('void', post)
      #end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_address(xml, options)

        addr = options[:billing_address] || options[:address]

        if addr
          x_addr = xml.add_element("Address")
          x_addr.add_element("BillingName").text = addr[:name] || ""

          if addr[:address1]
            x_addr.add_element("BillingAddress1").text = addr[:address1] || ""
            x_addr.add_element("BillingCity").text = addr[:city] || ""
            x_addr.add_element("BillingState").text = addr[:state] || ""
            x_addr.add_element("BillingZipcode").text = addr[:zip] || ""
          end
        end

      end

      def add_invoice(x_trans, options)
        if options[:order_id]
          order_id = options[:order_id].to_s
          ticket_number = order_id

          #truncate ticket number if longer than 6 digits (element PS requirement)
          if ticket_number.length > TICKET_MAX_LEN

            ticket_number = ticket_number[(ticket_number.length-TICKET_MAX_LEN)..ticket_number.length]

          end

          x_trans.add_element("ReferenceNumber").text = order_id
          x_trans.add_element("TicketNumber").text = ticket_number
        end
      end

      def add_payment(xml, payment)
        x_card = xml.add_element("Card")

        x_card.add_element("CardNumber").text = payment.number
        
        year = payment.year.to_s.chars.last(2).join.to_s.rjust(2, '0')
        month = payment.month.to_s.rjust(2, '0')

        x_card.add_element("ExpirationMonth").text = month
        x_card.add_element("ExpirationYear").text = year
      end

      def parse(xml_string)
        response = {}

        xml = REXML::Document.new(xml_string)

        root = response_element()

        response["trans_type"] = @type.underscore

        xml.elements.each("#{root}/Response/*") do |element|
          el = element.name.underscore
          if el == "card" || el == "transaction"
            element.elements.each("*") do |element2|
              el2 = element2.name.underscore
              if not response[el2].nil?
                raise "Ooops, was about to override #{el2}"
              end
              response[el2] = element2.text
            end
          else
            response[el] = element.text
          end
        end
        response
      end

      def commit(xml)
        url = (test? ? test_url : live_url)


        response = parse(ssl_post(url, xml.to_s,{
          'Accept-Encoding' => '',
          'Content-Type' => 'text/xml'
          }))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          test: test?
        )
      end

      def success_from(response)
        response["express_response_code"] == "0"
      end

      def message_from(response)
        response["express_response_message"]
      end

      def ascii_only(str)
        str.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/n,'').to_s
      end
    end
  end
end
