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

### Transitions

Extend your class with *Wesm* module and define transitions

```ruby
class OrderStateMachine
  extend Wesm

  transition :payment_verification => :paid, actor: Manager, performer: 'Payment'
  transition :paid => :shipping, actor: :supplier, required: [:supplier_billing_info, :shipping]
  transition :paid => :shipping_missed, actor: :consumer, required: :claim
  transition :rejected => :received, scope: { active_change: nil }, actor: [:consumer, OrdersSchedulerJob]
end
```

State can be changed with *perform_transition* method

```ruby
user = Manager.new
order = Order.new(state: 'payment_verification')

OrderStateMachine.perform_transition(order, user, 'paid')

order.state
=> "paid"
```

*successors* method shows list of allowed subsequent states

```ruby
order = Order.new(state: 'paid')

OrderStateMachine.successors(order)
=> ['shipping', 'shipping_missed']
```

*show_transitions* method shows list of allowed transitions for provided actor

```ruby
user = User.new
order = Order.new(state: 'paid', consumer: user)

OrderStateMachine.show_transitions(order, user)
=> {
     to_state: 'shipping_missed',
     is_authorized: true,
     can_perform: false,
     required_fields: [:claim]
   }
```

Transition logic should be implemented inside *process_transition* method  
Default implementation is just changing object's state

ActiveRecord example with persistence:

```ruby
class OrderStateMachine
  extend Wesm

  def self.process_transition(order, transition, actor)
    ActiveRecord::Base.transaction do
      # any actions
      order.state = transition.to_state
      order.save!
    end
  end
end
```
*process_transition* will accept all extra arguments passed to *perform_transition* method

Default field for object's mapping is *state* and can be set by overriding *state_field*

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
