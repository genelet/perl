package Genelet::APNS;

use Data::Dumper;
use strict;
use Net::SSLeay qw/die_now die_if_ssl_error/;
use Socket;
use JSON;

my %init = (
  logger => undef,

  port   => 2195,
  badge  => 0,

  sandbox=> undef,
  sound  => undef,

  alert => undef,
  device_token => undef,
  cert   => undef,
  key    => undef,
  passphrase => undef,
);

sub AUTOLOAD {
  my $self = shift;

  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;

  return if $attr =~ /[A-Z]/; # return if $attr eq 'DESTROY'
  die "Can't access $attr field." unless (exists($init{$attr}));

  $self->{uc $attr} = shift if (@_);
  return $self->{uc $attr};
}

sub new {
  my ($class, %args) = @_;
  my $self  = {};

  foreach my $attr (keys %init) {
    my $u = uc $attr;
    $self->{$u} = $args{$attr};
    $self->{$u} = $init{$attr} unless (defined($self->{$u}));
  }


  bless $self, $class;
  return $self;
}

sub alert {
  my $self = shift;

  $self->{ALERT} = shift if (@_);
  return $self->{ALERT};
}

sub badge {
  my $self = shift;

  $self->{BADGE} = shift if (@_);
  return $self->{BADGE};
}

sub port {
  my $self = shift;

  $self->{PORT} = shift if (@_);
  return $self->{PORT};
}

sub device_token {
  my $self = shift;

  $self->{DEVICE_TOKEN} = shift if (@_);
  return $self->{DEVICE_TOKEN};
}

sub passphrase {
  my $self = shift;

  $self->{PASSPHRASE} = shift if (@_);
  return $self->{PASSPHRASE};
}

sub payload {
  my $self = shift;
  my ($alert, $badge, $device_token) = @_;
  $alert ||= $self->{ALERT};
  $badge ||= $self->{BADGE};
  $device_token ||= $self->{DEVICE_TOKEN};
 
  return unless ($alert and $device_token);
  $badge ||= 1;

  my $data = { aps => { alert => $alert, badge => $badge } };
  $data->{aps}->{sound} = $self->{SOUND} if $self->{SOUND};
  $data->{custom} = $self->{CUSTOM} if $self->{CUSTOM};
  $data = JSON::encode_json($data);

   return chr(0) . pack( 'n',  32 ) . pack( 'H*', $device_token )
	. pack( 'n',  length($data) ) . $data;
}

sub send {
  my $self = shift;
  my $payload = $self->payload(@_) or return "no payload";

# $Net::SSLeay::trace       = 3;
# $Net::SSLeay::ssl_version = 10;
  Net::SSLeay::load_error_strings();
  Net::SSLeay::SSLeay_add_ssl_algorithms();
  Net::SSLeay::randomize();

  my ($socket, $ctx, $ssl);
  socket( $socket, PF_INET, SOCK_STREAM, getprotobyname('tcp') ) or return 1090;
  my $host = 'gateway.'.($self->{SANDBOX} ? 'sandbox.' : '').'push.apple.com';
  connect($socket, sockaddr_in($self->{PORT}, inet_aton($host))) or return 1091;

  $ctx = Net::SSLeay::CTX_new() or die_now "ctx: $!";
  Net::SSLeay::CTX_set_options( $ctx, &Net::SSLeay::OP_ALL );
  die_if_ssl_error("ctx set options");
  Net::SSLeay::CTX_set_default_passwd_cb( $ctx, sub { $self->passphrase } );
  Net::SSLeay::CTX_use_RSAPrivateKey_file( $ctx, $self->{KEY}, &Net::SSLeay::FILETYPE_PEM);
  die_if_ssl_error("private key");
  Net::SSLeay::CTX_use_certificate_file( $ctx, $self->{CERT}, &Net::SSLeay::FILETYPE_PEM);
  die_if_ssl_error("certificate");

  $ssl = Net::SSLeay::new($ctx);
  Net::SSLeay::set_fd( $ssl, fileno($socket) );
  Net::SSLeay::connect($ssl) or die_now "ssl connect: $!";
  Net::SSLeay::write($ssl, $payload);
  die_if_ssl_error("write payload");

  CORE::shutdown( $socket, 1 ) if $socket;
  Net::SSLeay::free($ssl) if defined($ssl);
  Net::SSLeay::CTX_free($ctx) if $ctx;
  close($socket) if $socket;
  return;
}

1;
