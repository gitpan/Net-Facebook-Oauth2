package Net::Facebook::Oauth2;

use strict;
use warnings;
our $VERSION = '0.01';
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
    
##example using catalyst framework
##It also can be used 
    
    use Net::Facebook::Oauth2;
    
    sub index : Private {
        
        my ( $self, $c ) = @_;
        my $params = $c->req->parameters;
        
        
        my $fb = Net::Facebook::Oauth2->new(
            application_id => 'your_application_id',  ##get this from your facebook developers platform
            application_secret => 'your_application_secret', ##get this from your facebook developers platform
        );
        
        #### first check if callback URL contains a verifier code  "code" parameter
        if ($params->{code}){
            
            ####second step, we recieved "verifier" code parameters, now get access token
            ###you need to pass the verifier code to get access_token
            
            my $access_token = $fb->get_access_token(code => $params->{code});
            
            ###save this token in database or session
            $c->res->body($access_token);
            
        }
        
        else {
            
            ##there is no verifier code passed so let's create authorization URL and redirect to it
            
            my $url = $fb->get_authorization_url(
                scope => ['offline_access','publish_stream'], ###pass scope/Extended Permissions params as an array telling facebook how you want to use this access
                callback => 'http://yourdomain.com/facebook',  ##Callback URL, facebook will redirect users after authintication
                display => 'page' ## how to display authorization page, other options popup "to display as popup window" and wab "for mobile apps"
            );
            
            $c->res->redirect($url);
            
            ###scope/Extended Permissions description
            ##offline_access : Allow your application to edit profile while user is not online
            ##publish_stream : read write access
            ##you can find more about facebook scopes/Extended Permissions at
            ##http://developers.facebook.com/docs/authentication/permissions
            
            
        }
        
        
        
        
    }
    
    ##Later in your application you can get/post to facebook on the behalf of the authorized user
    
    sub get : Local {
        
        my ( $self, $c ) = @_;
        my $params = $c->req->parameters;
        
       
        
        my $fb = Net::Facebook::Oauth2->new(
            access_token => 'ACCESS_TOKEN' ##Load previous saved access token for this user
        );
        
        ##lets get list of friends for the authorized user
        my $friends = $fb->get(
            'https://graph.facebook.com/me/friends' ##Facebook 'list friend' Graph API URL
        );
        
        $c->res->body($friends->as_json); ##as_json method will print response as json object
        
        ##lets search all posts with some keyword
        ##https://graph.facebook.com/search?q=watermelon&type=post
        
        my $topics = $fb->get(
            'https://graph.facebook.com/search', ##Facebook 'search' Graph API URL
            {
                q => 'Keyword',
                type => 'post'
            }
        );
        
        $c->res->body($friends->as_hash); ##as_hash method will print response as Perl hash
        
    }
    
    
    sub post : Local {
        
        my ( $self, $c ) = @_;
        my $params = $c->req->parameters;
        
        ###Lets post a message to the feed of the authorized user
        
        my $fb = Net::Facebook::Oauth2->new(
            access_token => 'ACCESS_TOKEN' ##Load previous saved access token for this user
        );
        
        
        my $res = $fb->post(
            'https://graph.facebook.com/me/feed', ###API URL
            {
                message => $extra->{facebook} ##hash of params/variables (param=>value)
            }
        );
        
        c->res->body($res->as_json);
        
    }
    
    
    
    

=head1 DESCRIPTION

Net::Facebook::Oauth2 gives you a way to simply access FaceBook Oauth 2.0 protocol

Please see the above example for more information on how to use this Module

=head1 SEE ALSO

For more information about Facebook Oauth 2.0 API

Please Check
http://developers.facebook.com/docs/

get/post Facebook Graph API
http://developers.facebook.com/docs/api



=head1 AUTHOR

Mahmoud A. Mehyar, E<lt>mamod.mehyar@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Mahmoud A. Mehyar

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
