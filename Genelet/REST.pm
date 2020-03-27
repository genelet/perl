package Genelet::REST;

use strict;
use Data::Dumper;
use JSON;
use URI::Escape;
use MIME::Base64;
use LWP::UserAgent;

use Genelet::Accessor;
use vars qw(@ISA);
@ISA = qw(Genelet::Accessor);

__PACKAGE__->setup_accessors(
    client_id     => "",
    client_secret => "",
	host          => "",
	realm         => "",

	target        => "",
	idname        => "id",

	req           => undef,
	access        => undef,
	access_token  => "",

	lists         => undef,
);

# generate request object using initial method, headers, and content
sub init_request {
	my $self    = shift;
	my $method  = shift;
	my $headers = shift;
	my $content = shift;

	$headers = [%$headers] if ($headers && (ref($headers) eq 'HASH'));
	$self->{REQ} = HTTP::Request->new($method, $self->goto(), $headers, $content);

	return;
}

# generate request object using initial method, headers, and content
# with a Bearer access token and json content type from now on
sub init_request_bearer {
	my $self    = shift;
	my $method  = shift;
	my $headers = shift;
	my $content = shift;

	$headers = [%$headers] if ($headers && (ref($headers) eq 'HASH'));
	$self->{REQ} = HTTP::Request->new($method, $self->{REALM}, $headers, $content);
	$self->{REQ}->header('Authorization' => $self->auth_header());

	my $ua = LWP::UserAgent->new();
	my $res = $ua->request($self->{REQ});
	if ($res->is_success) {
    	$self->{ACCESS} = decode_json($res->decoded_content);
    	$self->{ACCESS_TOKEN} = $self->{ACCESS}->{access_token};
		$self->{REQ}->header('Authorization'=> "Bearer ".$self->{ACCESS_TOKEN});
		$self->{REQ}->header('Content-Type' => "application/json");
		return;
	}

	return $res->status_line;
}

# function for the fisrt Authorization
sub auth_header {
    my $self = shift;
    return "Basic " . MIME::Base64::encode($self->{CLIENT_ID}.":".$self->{CLIENT_SECRET}, "");
}

# project url relative to host
sub goto {
	my $self = shift;
	my $id   = shift || '';
	return "https://".$self->{HOST}.$self->{TARGET}.$id;
}

# general product request, id is the part after generic target url
sub talk {
	my $self   = shift;
	my $method = shift;
	my $query  = shift;
	my $id     = shift;

	my $req = $self->{REQ};
	$req->method($method);

	my $res;
	if ($method eq 'GET' || $method eq 'DELETE') {
		my $rest = "";
		if ($query) {
			$rest = '?';
			$rest .= "$_=".uri_escape($query->{$_})."&" for (%$query);
			substr($rest, -1, 1) = '';
		}
		$req->uri($self->goto($id).$rest);
		$req->content('');
	} else {
		$req->uri($self->goto($id));
		$req->content(encode_json($query)) if ($req->header("Content-Type") eq 'application/json');
	}

	my $ua = LWP::UserAgent->new();
	my $res = $ua->request($req);
#warn Dumper $res;
	if ($res->is_success) {
		$self->{LISTS} = decode_json($res->decoded_content);
		return;
    }

	return ($res->decoded_content) ? decode_json($res->decoded_content) : $res->status_line;
}

# pass id in query, and add extra $name optionally
sub single {
	my $self = shift;
	my $method = shift;
	my $query = shift;
	my $name = shift;

	my $id = $query->{$self->{IDNAME}};
	return 1170 unless $id;
	$id = "/$id";
	$id .= "/$name" if $name;
	delete $query->{$self->{IDNAME}};
	return $self->talk($method, $query, $id);
}

# here we start 5 REST verbs
sub edit {
	my $self = shift;
	 return $self->single("GET", @_);
}

sub update {
	my $self = shift;
	return $self->single("PUT", @_);
}

sub insupd {
	my $self = shift;
	return $self->single("PATCH", @_);
}

sub delete {
	my $self = shift;
	return $self->single("DELETE", @_);
}

sub topics {
	my $self = shift;
	return $self->talk("GET", @_);
}

sub insert {
	my $self = shift;
	return $self->talk("POST", @_);
}

1;
