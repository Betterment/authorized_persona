require "pca/version"

require "rails"
require "active_model"

require "pca/persona"
require "pca/authorization"
require 'pca/view_helpers'

require "pca/railtie"

module PCA
  class Error < StandardError; end
end
