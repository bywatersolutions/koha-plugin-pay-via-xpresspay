package Koha::Plugin::Com::ByWaterSolutions::PayViaXpresspay::API;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use WWW::Form::UrlEncoded qw(parse_urlencoded);

sub handle_payment {
    my $c = shift->openapi->valid_input or return;

    my $body = $c->req->body;

    return $c->render( status => 204, text => q{} );

    if ( my %data = parse_urlencoded($body) ) {

        warn "handle_payment: " . Data::Dumper::Dumper( \%data );


        return $c->render( status => 204, text => q{} );
    }
    else {
        return $c->render(
            status  => 500,
            openapi => { error => "Unable to decode json" }
        );
    }
}

1;
