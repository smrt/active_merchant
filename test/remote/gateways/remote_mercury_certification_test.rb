require 'test_helper'
require "support/mercury_helper"

class RemoteMercuryCertificationTest < Test::Unit::TestCase
  include MercuryHelper

  def test_case1_1
    charge(card5,101)
  end

  def test_case1_2
    charge(card5,102,options('1'),gateway_5)
  end

  #def test_case1_3
  #  charge(card5,103,gateway_7)
  #end

  def test_case2_x
    charge(card4,104)
    charge(card3,105)
    charge(card2,106)
    charge(card5,107)
  end


  def test_case3_x
    sale = charge(card5,107,options('1'))
    capture = capture(107,card5,sale,options('1'))

    sale = charge(card5,107,options('2'))
    capture = capture(107,card5,sale,options('2'))

    sale = charge(card5,107,options('2'))
    capture = capture(107,card5,sale,options('test_case1_2'))

    assert_success sale
    assert_equal "AP", sale.params["text_response"]

  end


  def test_case4_1
    sale = charge(card4,108,options('1', billing_address: {
      address1: "1661 E. Camelback",
      zip: '85016'
    }))

    void(card4,sale,options)
  end

  def test_case4_2
    sale = charge(card3,109,options('1', billing_address: {
      address1: "2500 Lake Cook Road",
      zip: '60015'
    }))

    void(card3,sale,options)
  end


  def test_case4_3
    sale = charge(card3,110,options('1', billing_address: {
      address1: "4 Corporate SQ",
      zip: '30329'
    }))

    void(card3,sale,options)

  end


  private

  def void(card,sale,options)
    options[:credit_card] = card
    void = gateway_1.void(sale.authorization, options)
    
    assert_success void
    assert_equal "REVERSED", void.params["text_response"]
  end


  def charge(card, amount, options=nil, gateway=nil)
    gateway ||= gateway_1
    options ||= options('1')

    close_batch(gateway)

    sale = gateway.purchase(amount, card, options)
    assert_success sale
    assert_equal "AP", sale.params["text_response"]
    sale
  end

  def capture(amount,card,sale,options)
    options[:credit_card] = card
    gateway_1.capture(amount, sale.authorization, options)
  end

  def gateway_1()
    @gateway_1 ||= MercuryGateway.new(
      :login => "003503902913105",
      :password => "xyz",
      :tokenization => false,
      :merchant => 'test'
    )
  end

  def gateway_5()
      @gateway_5 ||= MercuryGateway.new(
        :login => "023358150511666",
        :password => "xyz",
        :tokenization => true,
        :merchant => 'test'
      )
  end
  
  def card4 
    @card4 ||= credit_card(
      "373953244361001",
      :brand => "amex",
      :month => "12",
      :year => "15",
      :verification_value => "1234"
    )

  end

  def card5
    @card5 ||= credit_card(
      "4005550000000480",
      :brand => "visa",
      :month => "12",
      :year => "15",
      :verification_value => "123"
    )
  end

  def card2
    @mc ||= credit_card(
      "5499990123456781",
      :brand => "master",
      :month => "12",
      :year => "15",
      :verification_value => "123"
    )
  end


  def card3
    @disc ||= credit_card(
      "6011000997235373",
      :brand => "discover",
      :month => "12",
      :year => "15",
      :verification_value => "362"
    )
  end

  def options(order_id=nil, other={})
    {
      :order_id => order_id,
      :description => "ActiveMerchant",
    }.merge(other)
  end
end
