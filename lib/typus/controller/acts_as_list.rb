module Typus
  module Controller
    module ActsAsList

      ##
      # This module is designed to work with `acts_as_list`.
      #
      # Available positions are:
      #
      # - move_to_top
      # - move_higher
      # - move_lower
      # - move_to_bottom
      #
      def position
        @item.send(params[:go])
        notice = Typus::I18n.t("%{model} successfully updated.", :model => @resource.model_name.human)
        redirect_to :back, :notice => notice
      end

    end
  end
end
