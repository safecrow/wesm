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

###Transitions

Extend your statemachine with `Wesm` module and define transitions

```ruby
module OrderStateMachine
  extend Wesm

  transition :awaits_payment => :paid
  transition :paid => :shipped
end
```

```ruby
@order = Order.new(state: 'awaits_payment')

OrderStateMachine.perform_transition(@order, current_user, 'paid')

order.state
=> "paid"
```

Field 'state' is used for transitions as default, it can be changed by overriding **state_field** method in your module, e.g

```ruby
def state_field
  :status
end
```

! Note that Wesm does not persist objects out of box and designed for plain ruby, this feature can be implemented by defining **persist_object** method in your module and it will be called during transition

ActiveRecord example
```ruby
module OrderStateMachine
  extend Wesm

  def persist_object(object, transition)
    object.save
  end
end
```

### Successors
  @ not documented yet
### Show available transitions
  @ not documented yet

### Transition actors

Wesm can encapsulate authorization logic like for example cancancan does

Authorized actor for performing transition can be defined by several ways:

```ruby
module OrderStateMachine
  extend Wesm

  transition :awaits_payment => :paid, actor: :consumer
  transition :paid => :shipped, actor: :supplier
  transition :pending => :approved, actor: Manager
  transition :received => :done, actor: OrderSchedulerJob
end

@order = Order.new(consumer: current_user, state: 'awaits_payment')

OrderStateMachine.perform_transition(@order, current_user, 'paid') # will succeed
```

Transition's actor also can be defined with array and it will work like OR
```ruby
transition :awaits_payment => :paid, actor: [:consumer, Manager]
```

### Required fields

```ruby
module OrderStateMachine
  extend Wesm

  transition :paid => :shipped, actor: :supplier, required: :shipping
end
```

This way transition *paid* > *shipped* is performable only if shipping field is not nil  
Required fields can be defined as array and it will work like AND

### Object constraints

For the purpose to scope transitions for different types of objects key **where** is available:

```ruby
module OrderStateMachine
  extend Wesm

  transition :rejected => :returned, actor: :consumer, where: { type: 'material' }
  transition :rejected => :done, where: { type: 'digital' }
  transition :done => :archived, where: { type: 'material', is_archivable: true }
  transition :pending => :approved, where: { billing_info: -> (billing_info) { ..something } }
end
```

Transition is performable only if all constraints pass


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/arthurweisz/wesm.
