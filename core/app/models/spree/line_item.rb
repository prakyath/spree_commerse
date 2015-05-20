module Spree
  class LineItem < Spree::Base
    before_validation :invalid_quantity_check
    belongs_to :order, class_name: "Spree::Order", inverse_of: :line_items, touch: true
    belongs_to :variant, class_name: "Spree::Variant", inverse_of: :line_items
    belongs_to :tax_category, class_name: "Spree::TaxCategory"

    has_one :product, through: :variant

    has_many :adjustments, as: :adjustable, dependent: :destroy
    has_many :inventory_units, inverse_of: :line_item

    before_validation :copy_price
    before_validation :copy_tax_category

    validates :variant, presence: true
    validates :quantity, numericality: {
      only_integer: true,
      greater_than: -1,
      message: Spree.t('validation.must_be_int')
    }
    validates :price, numericality: true
    validates_with Stock::AvailabilityValidator

    validate :ensure_proper_currency
    before_destroy :update_inventory
    before_destroy :destroy_inventory_units

    after_save :update_inventory
    after_save :update_adjustments

    after_create :update_tax_charge

    delegate :name, :description, :sku, :should_track_inventory?, to: :variant
    delegate :tax_zone, to: :order

    attr_accessor :target_shipment

    def copy_price
      if variant
        update_price if price.nil?
        self.cost_price = variant.cost_price if cost_price.nil?
        self.currency = variant.currency if currency.nil?
      end
    end

    def update_price
      self.price = variant.price_including_vat_for(tax_zone)
    end

    def copy_tax_category
      if variant
        self.tax_category = variant.tax_category
      end
    end

    extend DisplayMoney
    money_methods :amount, :subtotal, :discounted_amount, :final_amount, :total, :price

    alias single_money display_price
    alias single_display_amount display_price

    def amount
      price * quantity
    end
    alias subtotal amount

    def discounted_amount
      amount + promo_total
    end
    alias discounted_money display_discounted_amount

    def final_amount
      amount + adjustment_total
    end
    alias total final_amount
    alias money display_total

    def invalid_quantity_check
      self.quantity = 0 if quantity.nil? || quantity < 0
    end

    def sufficient_stock?
      Stock::Quantifier.new(variant).can_supply? quantity
    end

    def insufficient_stock?
      !sufficient_stock?
    end

    # Remove product default_scope `deleted_at: nil`
    def product
      variant.product
    end

    # Remove variant default_scope `deleted_at: nil`
    def variant
      Spree::Variant.unscoped { super }
    end

    def options=(options={})
      return unless options.present?

      opts = options.dup # we will be deleting from the hash, so leave the caller's copy intact

      currency = opts.delete(:currency) || order.try(:currency)

      if currency
        self.currency = currency
        self.price    = variant.price_in(currency).amount +
                        variant.price_modifier_amount_in(currency, opts)
      else
        self.price    = variant.price +
                        variant.price_modifier_amount(opts)
      end

      self.assign_attributes opts
    end

    private
      def update_inventory
        if (changed? || target_shipment.present?) && self.order.has_checkout_step?("delivery")
          Spree::OrderInventory.new(self.order, self).verify(target_shipment)
        end
      end

      def destroy_inventory_units
        inventory_units.destroy_all
      end

      def update_adjustments
        if quantity_changed?
          update_tax_charge # Called to ensure pre_tax_amount is updated.
          recalculate_adjustments
        end
      end

      def recalculate_adjustments
        Adjustable::AdjustmentsUpdater.update(self)
      end

      def update_tax_charge
        Spree::TaxRate.adjust(order, [self])
      end

      def ensure_proper_currency
        unless currency == order.currency
          errors.add(:currency, :must_match_order_currency)
        end
      end
  end
end
