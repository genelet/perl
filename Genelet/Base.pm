package Genelet::Base;

use strict;
use Digest::HMAC_SHA1;
use MIME::Base64 qw(encode_base64 decode_base64);

use Genelet::Accessor;
use vars qw(@ISA);
@ISA = ('Genelet::Accessor');

__PACKAGE__->setup_accessors(
  r      => undef,
  logger => undef,
  provider=>undef,

  ua     => undef,
  errors => undef,
  env    => {},
  storage=> undef,
  db     => [],
  chartags      => {},
  custom        => {},
  template      => '',
  document_root => '',
  project       => '',
  uploaddir     => '',
  server_url    => '',
  blks          => [],
  script        => '',
  pubrole       => '',
  comps         => [],

  secret        => '',
  action_name   => 'action',
  go_uri_name   => 'go_uri',
  role_name     => 'role',
  tag_name      => 'tag',
  component_name=> 'component',
  provider_name => 'provider',
  callback_name => 'callback',
  login_name    => 'login',
  loginas_name  => 'loginas',
  csrf_name     => 'csrf',

  logout_name   => 'logout',
  default_actions => {"GET"=>"topics", "GET_item"=>"edit", "PUT"=>"update", "POST"=>"insert", "DELETE"=>"delete", "PATCH"=>"insupd"}
);

sub dbh_trace {
  my $self = shift;
  my $dbh = shift;

  my $logger = $self->{LOGGER} or return;

  if ($logger->is_debug()) {
    $dbh->trace(2, $logger->filename());
  } elsif ($logger->is_notice()) {
    $dbh->trace(1, $logger->filename());
  }

  return;
}

sub warn {
  my $self = shift;

  return unless $self->{LOGGER};
  return $self->{LOGGER}->warn(@_);
}

sub debug {
  my $self = shift;

  return unless $self->{LOGGER};
  return $self->{LOGGER}->debug(@_);
}

sub info {
  my $self = shift;

  return unless $self->{LOGGER};
  return $self->{LOGGER}->info(@_);
}

sub notice {
  my $self = shift;

  return unless $self->{LOGGER};
  return $self->{LOGGER}->notice(@_);
}

sub error {
  my $self = shift;

  return unless $self->{LOGGER};
  return $self->{LOGGER}->error(@_);
}

sub critical {
  my $self = shift;

  return unless $self->{LOGGER};
  return $self->{LOGGER}->critical(@_);
}

sub alert {
  my $self = shift;

  return unless $self->{LOGGER};
  return $self->{LOGGER}->alert(@_);
}

sub emergency {
  my $self = shift;

  return unless $self->{LOGGER};
  return $self->{LOGGER}->emergency(@_);
}

sub digest64 {
  my $self = shift;
  my $key = shift;

  my $hmac = Digest::HMAC_SHA1->new($key);
  $hmac->add(join('', @_));
  return MIME::Base64::encode_base64($hmac->digest, '');
}

sub digest {
  my $self = shift;

  my $str = $self->digest64(@_); # old: sha1_base64(@_);
  $str =~ tr|+/=|\-_|d;
  return $str;
}
 
sub error_str {
  my $self = shift;
  my $code = shift;

  my %errors  = (
    1000 => "JSON to hash failed.",
    1001 => "Google authorization required.",
    1002 => "Facebook authorization required.",
    1003 => "User denied authorization.",
    1004 => "Failed in browser getting token.",
    1005 => "Failed in browser getting app.",
    1006 => "Failed in browser refreshing token.",
    1007 => "Failed in browser refreshing app.",
    1008 => "Failed in finding token.",
    1009 => "Twitter authorization required.",
    1010 => "Failed in retrieve token secret from db for twitter.",
    1011 => "Failed in getting user_id from twitter.",
    1013 => "Failed to get ticket from box.",
    
    1020 => "Login required.",
    1021 => "Not authorized to view the page.",
    1022 => "Login is expired.",
    1023 => "Your IP does not match the login credential.",
    1024 => "Login signature is not acceptable.",

    1030 => "Too many failed logins.",
    1031 => "Login incorrect. Please try again.",
    1032 => "System error.",
    1033 => "Web server configuration error.",
    1034 => "Login failed. Please try again.",
    1035 => "This input field is missing: ",
    1036 => "Please make sure your browser supports cookie.",
    1037 => "Missing Login or Password.",
	1038 => "HTTP Request Method for this action is not allowed.",

    1040 => "Empty field.",
    1041 => "Foreign key forced but its value not provided.",
    1042 => "Foreign key fields and foreign key-to-be fields do not match.",
    1043 => "Variable undefined in your customzied method.",
    1044 => "Variable undefined in your procedure method.",
    1045 => "Upload field not found.",
    1046 => "CSRF token not found.",
    1047 => "CSRF token not match.",
    1048 => "Upload field not found.",
    1049 => "Upload filename not found.",
    1050 => "Upload directory not found.",

    1051 => "Object method does not exist.",
    1052 => "Foreign key is broken.",
    1053 => "Foreign key session expired.",
    1054 => "Signature field not found.",
    1055 => "Signature not found.",
    1056 => "The signed column does not exist",

    1060 => "Email Server, Sender, From, To and Subject must be existing.",
    1061 => "Message is empty.",
    1062 => "Sending mail failed.",
    1063 => "Mail server not reachable.",
    1064 => "No message nor template.",
    1065 => "Missing mail template.",

    1070 => "Repeated pars in insupd",
    1071 => "Select Syntax error.",
    1072 => "Failed to connect to the database.",
    1073 => "SQL failed, check your SQL statement; or duplicate entry.",
    1074 => "Die from db.",
    1075 => "The record already exists",
    1076 => "Could not get a random ID.",
    1077 => "Condition not found in update.",
    1078 => "Hash not found in insert.",
    1079 => "Missing lists.",
	1080 => "Missing insupd pars.",
	1081 => "Hash not found in insupd.",
	1082 => "Not in multiple uniques.",
	1081 => "Not in unique.",

    1170 => "Missing ID.",
    1171 => "Failed insert, maybe existing",
    1172 => "Failed delete, check if FK exists",
    1173 => "Failed update",
    1174 => "Failed select due to wrong SQL statement or format",
    1175 => "Failed PROCEDURE",

    1080 => "Can't write to cache.",

    1090 => "No socket.",
    1091 => "Can't connect to socket.",
    1092 => "SSL error.",

    1100 => "Sender signature not found.",
    1101 => "Sender signature not confirmed.",
    1102 => "Invalid JSON.",
    1103 => "Incompatible JSON.",
    1105 => "Not allowed to send.",
    1106 => "Inactive recipient.",
    1107 => "Bounce not found.",
    1108 => "Bounce query exception.",
    1109 => "JSON required.",
    1110 => "Too many batch messages.",
    1111 => "HTTP email server error.",
    1113 => "Invalid email request.",
  );

  my $str;
  if ($self->{ERRORS}) {
    $str = ($self->{ERRORS} and $self->{ARGS} and $self->{ARGS}->{_gtag} and
		$self->{ERRORS}->{$self->{ARGS}->{_gtag}})
		? $self->{ERRORS}->{$self->{ARGS}->{_gtag}}->{$code}
		: $self->{ERRORS}->{$code};
  }
  return $str || $errors{$code} || $code;
}

sub ua_get {
  my $self = shift;

  return unless $self->{UA};
  my $response = $self->{UA}->get(@_);
  return unless $response->is_success();
  return $response->content();
}

sub ua_post {
  my $self = shift;

  return unless $self->{UA};
  my $response = $self->{UA}->post(@_);
  return unless $response->is_success();
  return $response->content();
}

sub ua_put {
  my $self = shift;

  return unless $self->{UA};
  my $response = $self->{UA}->put(@_);
  return unless $response->is_success();
  return $response->content();
}

sub ua_delete {
  my $self = shift;

  return unless $self->{UA};
  my $response = $self->{UA}->delete(@_);
  return unless $response->is_success();
  return $response->content();
}

1;
