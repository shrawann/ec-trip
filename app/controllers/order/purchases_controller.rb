class Order::PurchasesController < FrontBase
  before_action :authenticate_member!
  layout 'order'

  def new
    redirect_to member_carts_path and return if current_member.carts.blank? || current_member.carts.find {|cart| cart.item_error.present? }

    session[:purchase] ||= {}
    if params[:delivery_address_id].present? &&
        current_member.delivery_addresses.find_by(params[:delivery_address_id])
      session[:purchase]['delivery_address_id'] = params[:delivery_address_id]
    end
    if params[:credit_card_id].present? &&
        current_member.credit_cards.find_by(params[:credit_card_id])
      session[:purchase]['credit_card_id'] = params[:credit_card_id]
    end

    redirect_to order_invoice_address_path and return if current_member.invoice_address.blank?
    redirect_to order_delivery_addresses_path and return if current_member.delivery_addresses.blank?
    redirect_to order_credit_cards_path and return if current_member.credit_cards.blank?

    @purchase = current_member.purchases.build
    @purchase.set_attribute(session[:purchase]['delivery_address_id'], session[:purchase]['credit_card_id'])
  end

  def create
    @purchase = current_member.purchases.build
    @purchase.assign_attributes(post_params)
    if @purchase.new_order
      PurchaseCompleteJob.perform_later(@purchase)
      session[:purchase] = nil
      redirect_to complete_order_purchase_path(@purchase)
    else
      @purchase.set_amount
      render :new
    end
  end

  def complete
    @purchase = current_member.purchases.find(params[:id])
    render :complete, layout: 'front'
  end

  private
  def post_params
    params.require(:purchase).permit(
        :invoice_last_name, :invoice_first_name, :invoice_phone, :invoice_postal_code,
        :invoice_prefecture_id, :invoice_address1, :invoice_address2, :delivery_last_name, :delivery_first_name,
        :delivery_phone, :delivery_postal_code, :delivery_prefecture_id, :delivery_address1, :delivery_address2,
        :invoice_address_id, :delivery_address_id, :credit_card_id,
        details_attributes: [:item_id, :item_name, :price, :quantity]
    )
  end

end