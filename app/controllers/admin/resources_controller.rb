class Admin::ResourcesController < Admin::BaseController

  include Typus::Controller::Actions
  include Typus::Controller::Associations
  include Typus::Controller::Autocomplete
  include Typus::Controller::Filters
  include Typus::Controller::Format
  include Typus::Controller::Headless

  Whitelist = [:edit, :update, :destroy, :toggle, :position, :relate, :unrelate]

  before_filter :get_model
  before_filter :set_context # MultiSite ...
  before_filter :get_object, :only => Whitelist + [:show]
  before_filter :check_resource_ownership, :only => Whitelist
  before_filter :check_if_user_can_perform_action_on_resources

  ##
  # This is the main index of the model. With filters, conditions and more.
  #
  # By default application can respond to html, csv and xml, but you can add
  # your formats.
  #
  def index
    get_objects

    respond_to do |format|
      format.html do
        if headless_mode_with_custom_action_is_enabled?
          set_headless_resource_actions
        else
          add_resource_action(default_action.titleize, {:action => default_action}, {})
          add_resource_action("Trash", {:action => "destroy"}, {:confirm => "#{Typus::I18n.t("Trash")}?", :method => 'delete'})
        end
        generate_html
      end

      %w(json xml csv).each { |f| format.send(f) { send("generate_#{f}") } }
    end
  end

  def new
    item_params = params.slice *fields.keys
    item_params.delete_if { |k, v| !@resource.columns.map(&:name).include?(k) }
    @item = @resource.new(item_params, :without_protection => true)

    respond_to do |format|
      format.html # new.html.erb
      format.json { render :json => @item }
    end
  end

  ##
  # Create new items. There's an special case when we create an item from
  # another item. In this case, after the item is created we also create the
  # relationship between these items.
  #
  def create
    @item = @resource.new
    attributes = params[@object_name].slice *fields.keys
    @item.assign_attributes(attributes, :without_protection => true)

    set_attributes_on_create

    respond_to do |format|
      if @item.save
        format.html { redirect_on_success }
        format.json { render :json => @item, :status => :created, :location => @item }
      else
        format.html { render :action => "new" }
        format.json { render :json => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def show
    check_resource_ownership if @resource.typus_options_for(:only_user_items)

=begin
    respond_to do |format|
      format.html # show.html.erb
      format.xml { render :xml => @item }
      format.json { render :json => @item }
    end
=end
  end

  def update
    attributes = params[:attribute] ? { params[:attribute] => nil } : params[@object_name]
    attributes = attributes.slice *fields.keys

    respond_to do |format|
      role = admin_user.is_root? ? :admin : :default
      if @item.update_attributes(attributes, :without_protection => true)
        set_attributes_on_update
        format.html { redirect_on_success }
        format.json { render :json => @item }
      else
        format.html { render :edit }
        format.json { render :json => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    if @item.destroy
      notice = Typus::I18n.t("%{model} successfully removed.", :model => @resource.model_name.human)
    else
      alert = @item.errors.full_messages
    end
    redirect_to :back, :notice => notice, :alert => alert
  end

  def toggle
    @item.toggle(params[:field])

    respond_to do |format|
      if @item.save
        format.html do
          notice = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)
          redirect_to :back, :notice => notice
        end
        format.json { render :json => @item }
      else
        format.html { render :edit }
        format.json { render :json => @item.errors, :status => :unprocessable_entity }
      end
    end
  end

  private

  def get_model
    @resource = resource
    @object_name = ActiveModel::Naming.singular(@resource)
  end

  def resource
    params[:controller].extract_class
  end
  helper_method :resource

  def set_context
    @resource
  end
  helper_method :set_context

  def get_object
    @item = @resource.find(params[:id])
  end

  def get_objects
    set_scope
    set_wheres
    set_joins
    check_resources_ownership if @resource.typus_options_for(:only_user_items)
    set_order
    set_eager_loading
  end

  def fields
    @resource.typus_fields_for(params[:action])
  end
  helper_method :fields

  # Here we set the current scope!
  def set_scope
  end

  def set_wheres
    @resource.build_conditions(params).each do |condition|
      @resource = @resource.where(condition)
    end
  end

  def set_joins
    @resource.build_my_joins(params).each do |join|
      @resource = @resource.joins(join)
    end
  end

  def set_order
    params[:sort_order] ||= "desc"

    if (order = params[:order_by] ? "#{params[:order_by]} #{params[:sort_order]}" : @resource.typus_order_by).present?
      @resource = @resource.order(order)
    end
  end

  def set_eager_loading
    if (eager_loading = @resource.reflect_on_all_associations(:belongs_to).reject { |i| i.options[:polymorphic] }.map { |i| i.name }).any?
      @resource = @resource.includes(eager_loading)
    end
  end

  def redirect_on_success
    path = params.dup.cleanup

    # Redirects to { :action => 'index' }
    if params[:_save]
      path.delete_if { |k, v| %w(action id).include?(k) }
    end

    ##
    # Here what we basically do is to associate objects after they have been
    # created. It's similar to calling `relate` but which the difference that
    # we are creating a new record.
    #
    # We have two objects, detect the relationship_between them and then
    # call the related method.
    #
    if params[:_saveandassign]
      item_class = params[:resource].constantize
      # For some reason we are forced to set the /admin prefix to the controller
      # when working with namespaced stuff.
      options = { :controller => "/admin/#{item_class.to_resource}" }
      assoc = item_class.relationship_with(@resource).to_s
      unused_path, notice, alert = send("set_#{assoc}_association", item_class, options)
      path.merge!(:action => 'edit', :id => @item.id)
    end

    # Redirects to { :action => 'new' }
    if params[:_addanother]
      path.merge!(:action => 'new', :id => nil)
    end

    # Redirects to { :action => 'edit' => :id => @item.id }
    if params[:_continue]
      path.merge!(:action => 'edit', :id => @item.id)
    end

    message = (params[:action] == 'create') ? "%{model} successfully created." : "%{model} successfully updated."
    notice = Typus::I18n.t(message, :model => @resource.model_name.human)

    redirect_to path, :notice => notice
  end

  def default_action
    @resource.typus_options_for(:default_action_on_item)
  end

end
