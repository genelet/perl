package Genelet::Tree;

use strict;
use vars qw(@ISA @EXPORT $VERSION);

use Exporter;
$VERSION = 1.00;
@ISA = qw(Exporter);

@EXPORT = qw(tree_binary_column tree_make_children tree_make_list tree_all_children tree_all_parents);

sub tree_binary_column {
  my ($ref, $field_leg, $field_children, $top, $level, $column, $arr) = @_;

  return unless $ref->{$top}->{$field_children};

  foreach my $childid (@{$ref->{$top}->{$field_children}}) {
    my $newlevel = $level + 1;
    my $newcolumn = 2*$column + $ref->{$childid}->{$field_leg};
    $arr->[$newlevel]->[$newcolumn] = $childid;
    tree_binary_column($ref, $field_leg, $field_children,
        $childid, $newlevel, $newcolumn, $arr);
  }

  return;
}

sub tree_make_children { # assume ref having a field called 'parent'=>123456
  my ($ref, $field_parent, $field_children) = @_;

  foreach my $id (sort {$a<=>$b} keys %{$ref}) {
    my $parent = $ref->{$id}->{$field_parent} or next;
    push(@{$ref->{$parent}->{$field_children}}, $id)
        unless grep {$id==$_} @{$ref->{$parent}->{$field_children}};
  }

  return;
}

sub tree_make_list {
  my ($method, $ref, $field_parent, $field_children, $id, $level) = @_;

  return unless defined($ref->{$id});
  $method->($ref->{$id}, $level);

  foreach my $child (@{$ref->{$id}->{$field_children}}) {
    tree_make_list($method, $ref, $field_parent, $field_children, $child, 1+$level);
  }

  delete $ref->{$id};

  return;
}

sub tree_all_children { # assuming the list is ordered by tree_make_children
  my ($ref, $field_children, $id) = @_;

  return unless defined($ref->{$id}->{$field_children});

  my @all;
  foreach my $child (@{$ref->{$id}->{$field_children}}) {
    push @all, $child;
    my @trees = tree_all_children($ref, $field_children, $child);
    push(@all, @trees) if (@trees);
  }

  return @all;
}

sub tree_all_parents {
  my ($ref, $field_parent, $id) = @_;

  return unless defined($ref->{$id}->{$field_parent});

  my @all;
  push @all, $ref->{$id}->{$field_parent};
  my @trees = tree_all_parents($ref, $field_parent, $ref->{$id}->{$field_parent});
  push(@all, @trees) if (@trees);

  return @all;
}

1;
