require "support/active_record"
require "support/hash"
require "support/object"
require "support/string"

require "typus/engine"
require "typus/orm/base"
require "typus/orm/active_record"
require "typus/regex"
require "typus/version"

require "kaminari"

autoload :FakeUser, "support/fake_user"

module Typus

  autoload :Configuration, "typus/configuration"
  autoload :I18n, "typus/i18n"
  autoload :Resources, "typus/resources"

  module Controller
    autoload :Actions, "typus/controller/actions"
    autoload :ActsAsList, "typus/controller/acts_as_list"
    autoload :Ancestry, "typus/controller/ancestry"
    autoload :Associations, "typus/controller/associations"
    autoload :Autocomplete, "typus/controller/autocomplete"
    autoload :Bulk, "typus/controller/bulk"
    autoload :FeaturedImage, "typus/controller/featured_image"
    autoload :Filters, "typus/controller/filters"
    autoload :Format, "typus/controller/format"
    autoload :Headless, "typus/controller/headless"
    autoload :Multisite, "typus/controller/multisite"
    autoload :Trash, "typus/controller/trash"
  end

  module Authentication
    autoload :Base, "typus/authentication/base"
    autoload :Devise, "typus/authentication/devise"
    autoload :None, "typus/authentication/none"
    autoload :HttpBasic, "typus/authentication/http_basic"
    autoload :Session, "typus/authentication/session"
  end

  mattr_accessor :autocomplete
  @@autocomplete = nil

  mattr_accessor :admin_title
  @@admin_title = "Typus"

  mattr_accessor :admin_sub_title
  @@admin_sub_title = <<-CODE
<a href="http://core.typuscms.com/">core.typuscms.com</a>
  CODE

  ##
  # Available Authentication Mechanisms are:
  #
  # - none
  # - basic: Uses http authentication
  # - session
  #
  mattr_accessor :authentication
  @@authentication = :none

  mattr_accessor :config_folder
  @@config_folder = "config/typus"

  mattr_accessor :username
  @@username = "admin"

  ##
  # Pagination options passed to Kaminari helper.
  #
  #     :previous_label => "&larr; " + Typus::I18n.t("Previous")
  #     :next_label => Typus::I18n.t("Next") + " &rarr;"
  #
  # Note that `Kaminari` only accepts the following configuration options:
  #
  # - default_per_page (25 by default)
  # - window (4 by default)
  # - outer_window (0 by default)
  # - left (0 by default)
  # - right (0 by default)
  #
  mattr_accessor :pagination
  @@pagination = { :window => 0 }

  ##
  # Define a password.
  #
  # Used as default password for http and advanced authentication.
  #
  mattr_accessor :password
  @@password = "columbia"

  ##
  # Configure the e-mail address which will be shown in Admin::Mailer. If not
  # set `forgot_password` feature is disabled.
  #
  mattr_accessor :mailer_sender
  @@mailer_sender = nil

  ##
  # Define `paperclip` attachment styles.
  #

  mattr_accessor :file_preview
  @@file_preview = :medium

  mattr_accessor :file_thumbnail
  @@file_thumbnail = :thumb

  ##
  # Define `dragonfly` attachment styles.
  #

  mattr_accessor :image_preview_size
  @@image_preview_size = 'x650>'

  mattr_accessor :image_thumb_size
  @@image_thumb_size = 'x100'

  ##
  # Defines the default relationship table.
  #
  mattr_accessor :relationship
  @@relationship = "typus_users"

  mattr_accessor :master_role
  @@master_role = "admin"

  mattr_accessor :user_class_name
  @@user_class_name = "AdminUser"

  mattr_accessor :user_foreign_key
  @@user_foreign_key = "admin_user_id"

  mattr_accessor :quick_sidebar
  @@quick_sidebar = false

  class << self

    # Default way to setup typus. Run `rails generate typus` to create a fresh
    # initializer with all configuration values.
    def setup
      yield self
      reload!
    end

    def applications
      Typus::Configuration.config.map { |i| i.last["application"] }.compact.uniq.sort
    end

    # Lists modules of an application.
    def application(name)
      Typus::Configuration.config.map { |i| i.first if i.last["application"] == name }.compact.uniq
    end

    # Lists models from the configuration file.
    def models
      Typus::Configuration.config.map { |i| i.first }.sort
    end

    # Lists resources, which are tableless models. This is done by looking at
    # the roles, which handle the permissions for this kind of data.
    def resources
      if roles = Typus::Configuration.roles
        roles.keys.map do |key|
          Typus::Configuration.roles[key].keys
        end.flatten.sort.uniq.delete_if { |x| models.include?(x) }
      else
        []
      end
    end

    # Lists models under <tt>app/models</tt>.
    def detect_application_models
      model_dir = Rails.root.join("app/models")
      Dir.chdir(model_dir) { Dir["**/*.rb"] }
    end

    def application_models
      detect_application_models.map do |model|
        class_name = model.sub(/\.rb$/,"").camelize
        klass = class_name.split("::").inject(Object) { |klass,part| klass.const_get(part) }
        class_name if klass < ActiveRecord::Base && !klass.abstract_class?
      end.compact
    end

    def user_class
      user_class_name.constantize
    end

    def reload!
      Typus::Configuration.roles!
      Typus::Configuration.config!
    end

  end

end
