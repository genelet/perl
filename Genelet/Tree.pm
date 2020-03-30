package Genelet::Tree;

use strict;
use Data::Dumper;
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
  my ($ref, $field_children, $id, $level) = @_;
  $level ||= 1;

  my @all;
  return unless defined($ref->{$id}->{$field_children});

  foreach my $child (@{$ref->{$id}->{$field_children}}) {
    push @all, [$child, $level];
    my @trees = tree_all_children($ref, $field_children, $child, $level+1);
    push(@all, @trees) if (@trees);
  }

  return @all;
}

# see test
sub tree_all_parents {
  my ($ref, $field_parent, $id, $level) = @_;
  $level ||= 1;

  return unless defined($ref->{$id}->{$field_parent});

  my @all;
  push @all, [$ref->{$id}->{$field_parent}, $level];
  my @trees = tree_all_parents($ref, $field_parent, $ref->{$id}->{$field_parent}, $level+1);
  push(@all, @trees) if (@trees);

  return @all;
}

# see test
sub tree_hash_parents {
  my ($ref, $field_parent, $id, $level) = @_;
  $level ||= 1;

  return unless defined($ref->{$id});

  my @all;
  for my $item (@{$ref->{$id}}) {
    next unless $item->{$field_parent};
    push @all, {%$item, "_level", $level};
    my @trees = tree_hash_parents($ref, $field_parent, $item->{$field_parent}, $level+1);
    push(@all, @trees) if (@trees);
  }

  return @all;
}

# see test
# target is the targeted value of field_parent
# if found, the whole upline is in array, with the last being the target
sub tree_find_parents {
  my ($target, $ref, $field_parent, $id, $level) = @_;
  $level ||= 1;

  return unless defined($ref->{$id});

  my @all;
  for my $item (@{$ref->{$id}}) {
    next unless $item->{$field_parent};
    return if $item->{_found};
	if ($target eq $item->{$field_parent}) { # found ! return now
		push @all, {%$item, "_level", $level, "_found", 1};
		return @all;
	}
	if ($level==1) { # the last upline finds nothing, starts a new one
		@all = ({%$item, "_level", $level})
	} else {
    	push @all, {%$item, "_level", $level};
	}
    my @trees = tree_find_parents($target, $ref, $field_parent, $item->{$field_parent}, $level+1);
    push(@all, @trees) if (@trees);
	# if the last element in @trees is find, no more 'for' loop:
	my $finished = $trees[scalar(@trees)-1];
	return @all if $finished->{_found};
  }

  return @all;
}

1;
