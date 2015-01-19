require 'test_helper'

class RemoteElementExpressTest < Test::Unit::TestCase
  def setup
    @gateway = ElementExpressGateway.new(fixtures(:element_express))

    
    @visa_keyed = credit_card('4003002345678903',{month:12,year:2015})

    @master_keyed = credit_card('5499992345678903',{month:12,year:2015})

    @amex_keyed = credit_card('373953191351005',{month:9,year:2015})

    @discover_keyed = credit_card('6011000990191250',{month:12,year:2015})

    @options = {
      billing_address: address
    }
  end

  def test_dump_transcript
    #skip("Transcript scrubbing for this gateway has been tested.")

    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic
    #dump_transcript_and_fail(@gateway, 20, @credit_card, @options)
  end

  #def test_transcript_scrubbing
  #  transcript = capture_transcript(@gateway) do
  #    @gateway.purchase(@amount, @credit_card, @options)
  #  end
  #  transcript = @gateway.scrub(transcript)

  #  assert_scrubbed(@credit_card.number, transcript)
  #end

  def test_successful_purchase
    #skip("Not certifying")
    response = @gateway.purchase(100, @visa_keyed, @options)
    assert_success response
    assert_equal 'Approved', response.message

    assert_not_nil response.params["transaction_id"], 'trans id'

    assert_not_nil response.params["approval_number"], 'approval number'

    assert_not_nil response.params["avs_response_code"], 'avs'

    assert_equal response.params["express_response_code"], "0"
  end

  def test_failed_purchase
    #skip("Not certifying")
    @amount = 20 #FAIL Amount
    response = @gateway.purchase(20, @visa_keyed, @options)
    assert_failure response
    assert_equal 'Declined', response.message

  end


  def test_certification_card_sale
    #skip("Not certifying")
    log_trans(@gateway.purchase(204, @visa_keyed, @options))
    log_trans(@gateway.purchase(206, @master_keyed, @options))
    log_trans(@gateway.purchase(200, @amex_keyed, @options))
    log_trans(@gateway.purchase(200, @discover_keyed, @options))
  end

  def test_trans_credit
    #skip("Not certifying")
    response = @gateway.purchase(320, @visa_keyed, @options)

    assert_success response

    log_trans(response)

    transaction_id = response.params["transaction_id"]

    response2 = @gateway.credit(320, transaction_id)

    assert_success response2

    log_trans(response2)


    response3 = @gateway.credit(320, "INVALID_TRANS_ID")

    assert_failure response3
  end

  def test_void
    #skip("Not certifying")

    response = @gateway.purchase(509, @visa_keyed, @options)

    assert_success response

    log_trans(response)

    transaction_id = response.params["transaction_id"]

    response2 = @gateway.void(transaction_id)

    assert_success response2

    log_trans(response2)

  end

  def test_system_reversal
    #skip("Not certifying")
    order_id = "1921831"
    amount = 612
    response = @gateway.purchase(amount, @visa_keyed, {order_id: order_id})

    assert_success response

    log_trans(response)

    transaction_id = response.params["transaction_id"]

    response2 = @gateway.reversal(0, amount, @visa_keyed, {
      transaction_id: transaction_id,
      order_id: order_id
    })


    assert_success response2

    log_trans(response2)

  end

  def test_full_reversal
    #skip("Not certifying")
    order_id = "1921831"
    amount = 613
    response = @gateway.purchase(amount, @visa_keyed, {order_id: order_id})

    assert_success response

    log_trans(response)

    transaction_id = response.params["transaction_id"]

    response2 = @gateway.reversal(1, amount, @visa_keyed, {
      transaction_id: transaction_id,
      order_id: order_id
    })


    assert_success response2

    log_trans(response2)

  end
private

  def log_trans(response)
    #puts "======= TRANSACTION " + response.params["trans_type"] + " ======="
    #puts response.params["express_response_code"] + " / " + response.params["transaction_id"]
    #puts "==================================="
  end
end
