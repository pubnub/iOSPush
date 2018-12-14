from pubnub.pnconfiguration import PNConfiguration
from pubnub.pubnub import PubNub

CHANNEL = 'a'
PUB_KEY = 'pub-c-d0c2275e-d4fd-4d65-a37c-baf52e538ed5'
SUB_KEY = 'sub-c-9822fb8c-3214-11e8-bb03-624464779a54'

pnconfig = PNConfiguration()

pnconfig.subscribe_key = SUB_KEY
pnconfig.publish_key = PUB_KEY

pubnub = PubNub(pnconfig)


def publish_callback(envelope, status):
    # Check whether request successfully completed or not
    if not status.is_error():
        print 'Successfully published!'  # Message successfully published to specified channel.
    else:
        print 'Failed: %s' % (status)  # Handle message publish error. Check 'category' property to find out possible issue
        # because of which request did fail.
        # Request can be resent using: [status retry];

def generate_apns_payload(message):
    return {
        "pn_apns" : {
            "apns-collapse-id": 7,
            "aps" : {
                "alert" : message,
                "badge" : 2
            },
            "teams" : ["49ers", "raiders"],
            "score" : [7, 0]
        },
        "apns-collapse-id": 7,
    }

def main():
    pubnub.publish().channel(CHANNEL).message(generate_apns_payload('hello there!')).async(publish_callback)

if __name__ == '__main__':
    main()
