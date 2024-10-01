require "test_helper"

class PriceHistoriesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get price_histories_index_url
    assert_response :success
  end
end
