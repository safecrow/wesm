# Wesm

[![Build Status](https://travis-ci.org/arthurweisz/wesm.svg?branch=master)](https://travis-ci.org/arthurweisz/wesm)
[![Code Climate](https://codeclimate.com/github/arthurweisz/wesm/badges/gpa.svg)](https://codeclimate.com/github/arthurweisz/wesm)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wesm'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wesm

## Usage

### Specifying Transitions

Extend your class with *Wesm* module and define transitions with *transition* method

```ruby
class OrderStateMachine
  extend Wesm

  transition :pending => :approved, actor: Manager
  transition :pending => :rejected, actor: Manager, required: :reject_reason
  transition :approved => :payment_verification, actor: :owner, required: :payment
  transition :payment_verification => :paid, actor: StripePaymentsService
  transition :rejected => :closed, actor: [Manager, OrdersSchedulerJob]
end
```

### Performing transitions

```ruby
user = Manager.new
order = Order.new(state: 'pending')

OrderStateMachine.perform_transition(order, 'approved', user)

order.state
=> "approved"
```

Default implementation is just changing object's state  

You can customize it by overriding *process_transition* method which accepts **object**, **transition**, **actor** and all extra arguments passed to *perform_transition*  

ActiveRecord example with persistence:

```ruby
class OrderStateMachine
  extend Wesm

  def self.process_transition(object, transition, actor)
    ActiveRecord::Base.transaction do
      # any actions
      object.state = transition.to_state
      object.save!
    end
  end
end
```

### Subsequent transitions information

*successors* method can be used to list all possible subsequent states for transition regardless of actor and required fields

```ruby
order = Order.new(state: 'pending')

OrderStateMachine.successors(order)
=> ['approved', 'rejected']
```

*show_transitions* method shows list of allowed transitions for provided actor

```ruby
user = User.new
manager = Manager.new
order = Order.new(state: 'pending', owner: user)

OrderStateMachine.show_transitions(order, user)
=> [{
      to_state: 'approved',
      is_authorized: false,
      can_perform: false,
      required_fields: []
    },
    {
      to_state: 'rejected',
      is_authorized: false,
      can_perform: false,
      required_fields: [:reject_reason]
    }]

OrderStateMachine.show_transitions(order, manager)
=> [{
      to_state: 'approved',
      is_authorized: true,
      can_perform: true,
      required_fields: []
    },
    {
      to_state: 'rejected',
      is_authorized: true,
      can_perform: false,
      required_fields: [:reject_reason]
    }]
```
### State field  

Default field for object's mapping is **state** and can be set by overriding *state_field*

```ruby
class OrderStateMachine
  extend Wesm

  def self.state_field
    :custom_field
  end
end
```



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/arthurweisz/wesm.
