# AuthorizedPersona

AuthorizedPersona is an extremely simple, declarative Rails
authorization library implementing the Persona Centric Authorization
pattern that Betterment developed for their internal tooling.

Persona Centric Authorization is animated by the following observations:

* Organizations are made up of folks with different skill sets and
  responsibilities. For the purposes of this library, we'll call a
related set of skills and responsibilities a discipline, and the members
of a discipline a persona.
* An application built for a single persona will tend to be simpler,
  more coherent, and more comprehensible for both its users and
maintainers than an application attempting to serve many personas at
once.
* Within a persona, individuals need varying levels of access to
  systems based on their responsibilities, competency, accountability,
and trust levels in order to adhere to the principle of least privilege.
* Arbitrary matrix-based authorization schemes are complex and difficult
  to maintain consistently as organizations, applications and
responsibilities evolve.
* It is easier to find and avoid security vulnerabilities in simpler
  software.
* Code that doesn't exist in an app can't exhibit security
  vulnerabilities.
* You can only perform authorization when you have full relevant context
  both of who a user is, and what they are attempting to do.
* In the context of a database-backed application, it isn't an
  authorization library's job to define or validate access control
relationships between system users and data. This is your application's
domain.  Appropriate access controls will often emerge naturally from
your data model and trust root chaining. But even when more access
control logic is required, you will develop simpler, better-fit
solutions within your application.

Which led us to the following conclusions:

* Applications should be built for a single persona each.
* In Rails applications, authorization should be granted and enforced
  exclusively at the controller action grain because it is the only
layer in a Rails application with full context of the semantic action
being requested, and who is requesting it.
* In Rails applications, authorization logic should be limited to the
  view/presenter layer, where the full context of the request is
available.
* In an application built for a single persona, we only need to define a
  single privilege ladder where each tier's access is a superset of
the prior tier's in order to adhere to the principle of least privilege.

If that all sounds good to you, you should use AuthorizedPersona.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'authorized_persona'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install authorized_persona

## Usage

We'll assume you're using an authentication library like `devise` or
`clearance` that provides a `current_user` method.

1.  Integrate AuthorizedPersona into your user model.

The example uses ActiveRecord, but any ActiveModel-based ORM will do.
Your model only needs to have a string attribute named
`authorization_tier`.

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include AuthorizedPersona::Persona

  authorization_tiers(
    trainee: "Trainee - limited access",
    staff: "Staff - standard access",
    admin: "Admin - all access"
  )

  # You can use a custom attribute name, if desired, e.g.
  # self.authorization_tier_attribute_name = :auth_tier

  # If you want to use validations to keep bad data from making it into your table
  # do the following. The authorization_tier_names method is defined by AuthorizedPersona based
  # on the `authorization_tiers` declaration above.
  validates :authorization_tier, inclusion: { in: authorization_tier_names }

  # Your code here...
end
```

2. Add AuthorizedPersona to your base controller:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include AuthorizedPersona::Authorization

  # Any needed hooks your authentication library needs to ensure
  # `current_user` is set before # authorization, e.g.:
  #
  # before_filter :authenticate_user!

  authorize_persona class_name: "User"

  # or optionally override the method name we use to fetch current_[class_name] e.g.:
  #
  # authorize_persona class_name: "User", current_user_method_name: :current_fancy_user

  # Your code here...
end
```

At this point, no user is authorized to make a request to any descendent
of `ApplicationController`.

3. Grant privileges in your base controller or any subclass:

```ruby
# app/controllers/comments_controller.rb
class CommentsControlller < ApplicationController
  grant(
    trainee: [:index, :show],
    staff: :all
  )

  def index
    # ...
  end

  def show
    # ...
  end

  def create
    # ...
  end
end
```

In the scenario above, trainees will only be authorized to `index` and
`show` comments. Staff and above (including admins) will be able to
`create` comments as well (as well as any other actions that may be
defined).

Grants are inherited by subclasses, but every grant encountered
completely overrides any previous grants. This is by design to prevent
accidental privilege leakage into high-security controllers. If you see
a grant definition in a controller, you can be confident that that is
the complete definition for that controller and that no other grants
apply.

4. Make display decisions based on authorization in your views:

```erb
<%# app/views/home/index.html.erb %>

<% if authorized_to?(:create, :comment) %>
  <%= link_to("Comment...", new_comment_path) %>
<% end %>
```

5. (Advanced) If you need to segment data access by authorization tier, in your
   presenters:

```ruby
# app/presenters/bill_search.rb
class BillSearch
  attr_reader :searcher, :query

  def initialize(searcher:, query:)
    @searcher = searcher
    @query = query
  end

  def bills
    # AuthorizedPersona::Persona provides #[tier]_and_above? methods for all defined tiers
    relation = searcher.admin_or_above? ? Bills.all : Bills.nonsensitive
    relation.where('title like ?', query)
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Betterment/authorized_persona. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the AuthorizedPersona project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/Betterment/authorized_persona/blob/master/CODE_OF_CONDUCT.md).
