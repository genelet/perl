package Genelet::Accessor;

use strict;
use warnings;
use NEXT;

my %init_by_class;

sub setup_accessors {
  my ($class, %init) = @_;

  if ($init_by_class{$class}) {
    $init_by_class{$class} = {%{$init_by_class{$class}}, %init};
  } else {
    $init_by_class{$class} = \%init;
  }
    
  # Setup standard accessors.
  for my $attr (keys %init) {
    # We intend to mess with the symbol table.
    no strict 'refs';
    my $u = uc($attr);
    *{"$class\::$attr"} = sub {
      my $self = shift;
      $self->{$u} = shift if @_;
      return $self->{$u};
    } unless $class->can($attr);
  }

  # And create an initialization method.
  no strict 'refs';
  *{"$class\::__INIT__"} = sub {
    my ($self, %args) = @_;
    my $init = $init_by_class{$class};
    for my $attr (keys %$init) {
      my $u = uc($attr);
      if (exists $self->{$u}) {
        # A subclass populated this.
      } elsif (exists $args{$attr}) {
        # Take from args.
        $self->{$u} = $args{$attr};
      } else {
        my $value = $init->{$attr};
        if (ref($value) and ref($value) eq 'SUB') {
          # Dynamically generated attribute here.
          $self->{$u} = $value->($self, %args);
        } else {
          # Static attribute here.
          $self->{$u} = $value;
        }
      }
    }
  } unless *{"$class\::__INIT__"}{CODE};
}

sub new {
  my ($class, %args) = @_;
  my $self = bless {}, $class;
  # Going every first means child classes gets to populate fist.
  $self->EVERY::__INIT__(%args);
  # Reverse the order so that child classes get to override last.
  $self->EVERY::LAST::_new(%args);
  return $self;
}

1;
