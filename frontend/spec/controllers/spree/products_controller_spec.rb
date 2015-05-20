require 'spec_helper'

describe Spree::ProductsController, :type => :controller do
  let!(:product) { create(:product, :available_on => 1.year.from_now) }

  # Regression test for #1390
  it "allows admins to view non-active products" do
    allow(controller).to receive_messages :spree_current_user => mock_model(Spree.user_class, :has_spree_role? => true, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    spree_get :show, :id => product.to_param
    expect(response.status).to eq(200)
  end

  it "cannot view non-active products" do
    spree_get :show, :id => product.to_param
    expect(response.status).to eq(404)
  end

  it "should provide the current user to the searcher class" do
    user = mock_model(Spree.user_class, :last_incomplete_spree_order => nil, :spree_api_key => 'fake')
    allow(controller).to receive_messages :spree_current_user => user
    expect_any_instance_of(Spree::Config.searcher_class).to receive(:current_user=).with(user)
    spree_get :index
    expect(response.status).to eq(200)
  end

  # Regression test for #2249
  it "doesn't error when given an invalid referer" do
    current_user = mock_model(Spree.user_class, :has_spree_role? => true, :last_incomplete_spree_order => nil, :generate_spree_api_key! => nil)
    allow(controller).to receive_messages :spree_current_user => current_user
    request.env['HTTP_REFERER'] = "not|a$url"

    # Previously a URI::InvalidURIError exception was being thrown
    expect { spree_get :show, :id => product.to_param }.not_to raise_error
  end

end
