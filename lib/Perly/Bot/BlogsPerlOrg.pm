
# this might specialize in one or both classes
package Perly::Bot::BlogsPerlOrg {
	sub feed_class { 'Perly::Bot::Feed::BlogsPerlOrg' }
	sub post_class { 'Perly::Bot::Feed::Post::BlogsPerlOrg' }
	}

# keep these together in one file?

# so far, a null subtest

package Perly::Bot::Feed::BlogsPerlOrg {
	use parent qw(Perly::Bot::Feed);

	}

package Perly::Bot::Feed::Post::BlogsPerlOrg {
	use parent qw(Perly::Bot::Feed::Post);


	}

1;
