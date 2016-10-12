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

Extend your statemachine with `Wesm` module and define transitions with it's constraints

```ruby
module OrderStatemachine
  extend Wesm

  transition :awaits_payment => :paid, actor: :consumer
  transition :paid => :shipped, actor: :supplier, required: :shipping
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/arthurweisz/wesm.
