module PCA
  class Railtie < Rails::Railtie
    initializer "pca.view_helpers" do
      ActionView::Base.send :include, PCA::ViewHelpers
    end
  end
end
