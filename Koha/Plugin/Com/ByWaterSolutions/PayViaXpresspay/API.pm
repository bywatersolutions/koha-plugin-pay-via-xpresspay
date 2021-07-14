package Koha::Plugin::Com::ByWaterSolutions::PayViaXpresspay::API;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use WWW::Form::UrlEncoded qw(parse_urlencoded);

sub handle_payment {
    my $c = shift->openapi->valid_input or return;

    my $body = $c->req->body;

    return $c->render( status => 204, text => q{} );

    if ( my %data = parse_urlencoded($body) ) {
        my $twilio_status = $data{CallStatus};

        warn "TWILIO: update_message_status(): " . Data::Dumper::Dumper( \%data );

        my $status = $twilio_status eq 'queued'      ? 'sent'   : # We should get another status update later
                     $twilio_status eq 'ringing'     ? 'sent'   : # Ditto
                     $twilio_status eq 'in-progress' ? 'sent'   : # The person picked up, basically completed
                     $twilio_status eq 'completed'   ? 'sent'   : # Clearly completed
                     $twilio_status eq 'busy'        ? 'failed' : # TODO: Make retrying busy a plugin setting
                     $twilio_status eq 'failed'      ? 'failed' : # Phone number was most likely invalid
                     $twilio_status eq 'no-answer'   ? 'failed' : # See TODO above
                                                       'failed' ; # Staus was something we didn't expect
        $message->status($status);
        $message->store();

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
