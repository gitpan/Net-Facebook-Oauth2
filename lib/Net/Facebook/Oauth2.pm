package Net::Facebook::Oauth2;

use strict;
use warnings;
our $VERSION = '0.02';
use LWP::UserAgent;
use URI::Escape;
use JSON::Any;

sub new {
    
    my ($class,%options) = @_;
    
    my $self = {};
    $self->{options} = \%options;
    $self->{browser} = LWP::UserAgent->new;
    $self->{access_token_url} = $options{access_token_url} || "https://graph.facebook.com/oauth/access_token";
    $self->{authorize_url} = $options{authorize_url} || "https://graph.facebook.com/oauth/authorize";
    $self->{access_token} = $options{access_token};
    $self->{display} = $options{display} || 'page'; ##other values popup and wab
    return bless($self, $class);
  
}

sub get_authorization_url {
    
    my ($self,%params) = @_;
    
    $params{callback} = $self->{options}->{callback} unless defined $params{callback};
    die "You must pass a callback parameter with Oauth v2.0" unless defined $params{callback};
    
    $params{display} = $self->{display} unless defined $params{display};
    
    
    $self->{options}->{callback} = $params{callback};
    
    my $scope = join(",", @{$params{scope}}) if defined($params{scope});
    
    my $url = $self->{authorize_url}."?client_id=".$self->{options}->{application_id}."&redirect_uri=".$params{callback};
    $url = $url."&scope=$scope" if $scope;
    $url = $url."&display=".$params{display};
    
    return $url;
    
}


sub get_access_token {
    
    my ($self,%params) = @_;
    
    
    $params{code} = $self->{options}->{code} unless defined $params{code};
    die "You must pass a code parameter with Oauth v2.0" unless defined $params{code};
    
    $self->{options}->{code} = $params{code};
    
    my $getURL = $self->{access_token_url}."?client_id=".$self->{options}->{application_id}."&redirect_uri=".$self->{options}->{callback}."&client_secret=".$self->{options}->{application_secret}."&code=$params{code}";

    
    my $response = $self->{browser}->get($getURL);
    
    if ($response->{_rc} =~ /40/){
        my $j = JSON::Any->new;
        my $error = $j->jsonToObj($response->content());
        die "'".$error->{error}->{type}."'"." ".$error->{error}->{message};
    }
    
    my $file = $response->content();
    my ($access_token,$expires) = split(/&/, $file);
    my ($string,$token) = split(/=/, $access_token);
    
    #die 'Verifier Code is not valid' if !$token;
    
    $self->{access_token} = $token if $token;
    
    return $token;
    
}



sub _content {
    
    my ($self,$content) = @_;
    $self->{content} = $content;
    return $self;
    
}


sub get {
    
    my ($self,$url,$params) = @_;
    
    die "You must pass access_token" unless defined $self->{access_token};
    
    ##construct the new url
    my @array;
    
    
    
    while ( my ($key, $value) = each(%{$params})){
        $value = uri_escape($value);
        push(@array, "$key=$value");
    }

    my $string = join('&', @array);
    
    $url = $url."?access_token=".$self->{access_token};
    
    $url = $url."&".$string if $string;
    
    my $response = $self->{browser}->get($url);
    my $file = $response->content();
    return $self->_content($file);
    
}


sub post {
    
    my ($self,$url,$params) = @_;
    
    die "You must pass access_token" unless defined $self->{access_token};
    
    $params->{access_token} = $self->{access_token};
    
    my $response = $self->{browser}->post($url,$params);
    my $file = $response->content();
    return $self->_content($file);
    
}

sub as_hash {
    
    my ($self) = @_;
    my $j = JSON::Any->new;
    return $j->jsonToObj($self->{content});
    
}



sub as_json {
    
    my ($self) = @_;
    return $self->{content};
    
}


1;


=head1 NAME

Net::Facebook::Oauth2 - a simple Perl wrapper around Facebook OAuth v2.0 protocol

=head1 SYNOPSIS

use CGI;
my $cgi = CGI->new;

use Net::Facebook::Oauth2;

my $fb = Net::Facebook::Oauth2->new(
    application_id => 'your_application_id', 
    application_secret => 'your_application_secret'
);

###get authorization URL for your application
my $url = $fb->get_authorization_url(
    scope => ['offline_access','publish_stream'],
    callback => 'http://yourdomain.com/facebook/callback',
    display => 'page'
);

####now redirect to this url
print $cgi->redirect($url);


##once user vauthorize your application facebook will send him/her back to your application
##to the callback link provided above

###in your callback block capture verifier code and get access_token

my $fb = Net::Facebook::Oauth2->new(
    application_id => 'your_application_id',
    application_secret => 'your_application_secret'
);

my $access_token = $fb->get_access_token(code => $cgi->param('code'));
###save this token in database or session

##later on your application you can use this verifier code to comunicate
##with facebook on behalf of this user

my $fb = Net::Facebook::Oauth2->new(
    access_token => $access_token
);

my $info = $fb->get(
    'https://graph.facebook.com/me' ##Facebook API URL
);


print $info->as_json;
    
    
    

=head1 DESCRIPTION

Net::Facebook::Oauth2 gives you a way to simply access FaceBook Oauth 2.0 protocol

For more information please see example folder shipped with this Module

=head1 SEE ALSO

For more information about Facebook Oauth 2.0 API

Please Check
http://developers.facebook.com/docs/

get/post Facebook Graph API
http://developers.facebook.com/docs/api

=head1 USAGE

=head2 C<Net::Facebook::Oauth-E<gt>new( %args )>

Pass args as hash. C<%args> are:

=over 4

=item * C<application_id >

Your application id as you get from facebook developers platform
when you register your application

=item * C<application_secret>

Your application secret id as you get from facebook developers platform
when you register your application

=back

=head2 C<$fb-E<gt>get_authorization_url( %args )>

Return an Authorization URL for your application, once you receive this
URL redirect user there in order to authorize your application

=over 4

=item * C<scope>

['offline_access','publish_stream',...]

Array of Extended permissions as described by facebook Oauth2.0 API
you can get more information about scope/Extended Permission from
http://developers.facebook.com/docs/authentication/permissions

=item * C<callback>

callback URL, where facebook will send users after they authorize
your application

=item * C<display>

How to display Facebook Authorization page

=over 4

=item * C<page>

This will display facebook authorization page as full page

=item * C<popup>

This option is useful if you want to popup authorization page
as this option tell facebook to reduce the size of the authorization page

=item * C<wab>

From the name, for wab and mobile applications this option is the best
facebook authorization page will fit there :)

=back

=back

=head2 C<$fb-E<gt>get_access_token( %args )>

Returns access_token string
One arg to pass

=over 4

=item * C<code>

This is the verifier code that facebook send back to your
callback URL once user authorize your app, you need to capture
this code and pass to this method in order to get access_token

Verifier code will be presented with your callback URL as code
parameter as the following

http://your-call-back-url.com?code=234er7y6fdgjdssgfsd...

When access token is returned you need to save it in a secure
place in order to use it later in your application

=back

=head2 C<$fb-E<gt>get( $url,$args )>

Send get request to facebook and returns response back from facebook

=over 4

=item * C<url>

Facebook Graph API URL as string

=item * C<$args>

hashref of parameters to be sent with graph API URL if required

=back

The response returned can be formatted as the following

=over 4

=item * C<$responseE<gt>as_json>

Returns response as json object

=item * C<$responseE<gt>as_hash>

Returns response as perl hashref

=back

For more information about facebook grapg API, please check
http://developers.facebook.com/docs/api

=head2 C<$fb-E<gt>post( $url,$args )>

Send post request to facebook API, usually to post something

=over 4

=item * C<url>

Facebook Graph API URL as string

=item * C<$args>

hashref of parameters to be sent with graph API URL

=back

For more information about facebook grapg API, please check
http://developers.facebook.com/docs/api

=head1 AUTHOR

Mahmoud A. Mehyar, E<lt>mamod.mehyar@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Mahmoud A. Mehyar

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
