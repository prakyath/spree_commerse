require 'spec_helper'

describe Spree::Price, :type => :model do
  describe 'validations' do
    let(:variant) { stub_model Spree::Variant }
    subject { Spree::Price.new variant: variant, amount: amount }

    context 'when the amount is nil' do
      let(:amount) { nil }
      it { is_expected.to be_valid }
    end

    context 'when the amount is less than 0' do
      let(:amount) { -1 }

      it 'has 1 error_on' do
        expect(subject.error_on(:amount).size).to eq(1)
      end
      it 'populates errors' do
        subject.valid?
        expect(subject.errors.messages[:amount].first).to eq 'must be greater than or equal to 0'
      end
    end

    context 'when the amount is greater than 999,999.99' do
      let(:amount) { 1_000_000 }

      it 'has 1 error_on' do
        expect(subject.error_on(:amount).size).to eq(1)
      end
      it 'populates errors' do
        subject.valid?
        expect(subject.errors.messages[:amount].first).to eq 'must be less than or equal to 999999.99'
      end
    end

    context 'when the amount is between 0 and 999,999.99' do
      let(:amount) { 100 }
      it { is_expected.to be_valid }
    end
  end

  describe '#price_including_vat_for(zone)' do
    let(:variant) { stub_model Spree::Variant }
    let(:default_zone) { Spree::Zone.new }
    let(:zone) { Spree::Zone.new }
    let(:amount) { 10 }
    let(:tax_category) { Spree::TaxCategory.new }
    subject { Spree::Price.new variant: variant, amount: amount }

    context 'when called with a non-default zone' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(subject).to receive(:default_zone).at_least(:once).and_return(default_zone)
        allow(subject).to receive(:apply_foreign_vat?).and_return(true)
        allow(subject).to receive(:included_tax_amount).with(default_zone, tax_category) { 0.19 }
        allow(subject).to receive(:included_tax_amount).with(zone, tax_category) { 0.25 }
      end

      it "returns the correct price including another VAT to two digits" do
        expect(subject.price_including_vat_for(zone)).to eq(10.50)
      end
    end

    context 'when called from the default zone' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(subject).to receive(:default_zone).at_least(:once).and_return(zone)
      end

      it "returns the correct price" do
        expect(subject).to receive(:price).and_call_original
        expect(subject.price_including_vat_for(zone)).to eq(10.00)
      end
    end

    context 'when no default zone is set' do
      before do
        allow(variant).to receive(:tax_category).and_return(tax_category)
        expect(subject).to receive(:default_zone).at_least(:once).and_return(nil)
      end

      it "returns the correct price" do
        expect(subject).to receive(:price).and_call_original
        expect(subject.price_including_vat_for(zone)).to eq(10.00)
      end
    end
  end

  describe '#display_price_including_vat_for(zone)' do
    subject { Spree::Price.new amount: 10 }
    it 'calls #price_including_vat_for' do
      expect(subject).to receive(:price_including_vat_for)
      subject.display_price_including_vat_for(nil)
    end
  end
end
