#!/usr/bin/perl

#Werewolf bot

use strict;
use warnings;
use POE qw(Component::IRC Component::IRC::Plugin::Connector);
#use Math::Random::MT qw(srand rand);

###################
## Configuration ##
###################
my $nickname = 'Wolfbot';
my $ircname = 'Wolfbot to manage IRC Werewolf games';
#IRC Server to connect to
my $ircserver = '';
my $port = 6667;
#Channel to play the game in. This should be a dedicated channel. Include '#'
my $mainchannel = '';
#Nickname of user who can then give administrative orders to the bot
my $ownernick = '';
#By prepending this passphrase to a command, anyone can give admin orders
#Do not leave this empty or all orders will match it!
my $passphrase = '';
# Password to identify with NickServ
my $loginpass = '';
##########################
## End of configuration ##
##########################

my $nextevent;
my $playerlimit = 4;
my %playerlist = ();
my %votelist = ();
my %killlist = ();
#my $scan = '';
my %scan = ();
#my $protect = '';
my %protect = ();
my $doppletarget = '';
my $mode = 0;
# 0 - not playing (this is a little redundant, but 
# 1 - normal
# 2 - secret startrek mode
my $forcenight = 0;
my $forceday = 0;
my $randomroles = 0;
my $toggleseer = 1;
my $toggleangel = 1;
my $toggledoppleganger = 1;
my $toggleidiot = 1;
my $togglefinder = 1;
my %find = ();
my $gamestate = 0;
# 0 - not playing
# 1 - registration
# 2 - nighttime
# 3 - daytime (pre-vote)
# 4 - daytime (voting)
my @taketime = ( 60 , 60 , 90 , 30 );
my %texts = (
	1 => {
		start => 'A game of Werewolf has begun! You have TIME seconds to register. You can register by typing "/msg Wolfbot join" and you will be added to the game. You only need to send the message once, but don\'t worry if you accidentally send it twice, it won\'t cause the bot to crash or anything.',
		who_started => 'PERSON has started a game of werewolf!',
		who_joined => 'PERSON has joined the game!',
		reg_closed => 'Registration has closed.',
		not_enough => 'Game cancelled. At least AMOUNT players are required to begin a game.',
		is_wolf => 'You are a wolf! At night, choose your victim wisely, as you and the other wolves (if there are other wolves this game) will only be able to kill one person per night.',
		is_wolf_list => 'The wolves are: WOLFLIST',
		is_seer => 'You are the seer! At night, you may choose to reveal the identity of one other person. Only you will recieve this information, so be careful about revealing it. The wolf (or wolves) will surely kill you if they know who you are.',
		is_angel => 'You are the angel! At night, you may choose one person (other than yourself) to make immune to the attacks of werewolves. Be careful to reveal your role, the wolf (or wolves) will surely kill you if they know who you are.',
		is_doppleganger => 'You are the doppleganger! At night, you may choose one person (other than yourself) to copy their role. The change is permenant, and you can choose not to have it happen, but choose wisely.',
		is_village_idiot => 'You are the village idiot! You\'re a normal villager like all the rest... except your goal is to be lynched. If you succeed, you win the game.',
		is_finder => 'You are the finder! At night, you may choose one person (other than yourself). At daybreak, you will find out who they targetted (if anyone), though you won\'t find out what their role is. Using information gathered this way, you must try to find out who your enemies are.',
		is_villager_inform => 'If you did not receive a message, assume you are a villager.',
		who_died_wolf => 'PERSON was a wolf!',
		who_died_seer => 'PERSON was the seer.',
		who_died_angel => 'PERSON was the angel.',
		who_died_doppleganger => 'PERSON was the doppleganger.',
		who_died_village_idiot => 'PERSON was the village idiot!',
		who_died_finder => 'PERSON was the finder.',
		who_died_villager => 'PERSON was a normal villager.',
		who_died_general => 'PERSON was not a wolf.',
		time_night => 'It is currently night. All the villagers are fast asleep, tucked away in their beds and awaiting sunrise, which is in TIME seconds.',
		wolf_instruct => 'Wolf (or wolves), you have TIME seconds to send me the name of your victim. Just type "/msg Wolfbot kill <name>". If there is a tie, a victim will be randomly selected.',
		seer_instruct => 'Seer, you have TIME seconds to send me the name of the person you want to scan. Just type "/msg Wolfbot see <name>".',
		angel_instruct => 'Angel, you have TIME seconds to send me the name of the person you want to protect. Just type "/msg Wolfbot shield <name>".',
		doppleganger_instruct => 'Doppleganger, you have TIME seconds to send me the name of the person you want to dopple. Just type "/msg Wolfbot dopple <name>".',
		finder_instruct => 'Finder, you have TIME seconds to send me the name of the person whose target you want to discover. Just type "/msg Wolfbot find <name>".',
		set_wolf_target => 'You have set your target to PERSON.',
		change_wolf_target => 'You have changed your target to PERSON.',
		set_seer_target => 'You have set your target to PERSON.',
		change_seer_target => 'You have changed your target to PERSON.',
		set_angel_target => 'You have set your target to PERSON.',
		change_angel_target => 'You have changed your target to PERSON.',
		set_doppleganger_target => 'You have set your target to PERSON.',
		change_doppleganger_target => 'You have changed your target to PERSON.',
		set_finder_target => 'You have set your target to PERSON.',
		change_finder_target => 'You have changed your target to PERSON.',
		seer_reveal_wolf => 'PERSON is a wolf!',
		seer_reveal_seer => 'PERSON is a seer!',
		seer_reveal_angel => 'PERSON is an angel!',
		seer_reveal_doppleganger => 'PERSON is a doppleganger!',
		seer_reveal_finder => 'PERSON is a finder!',
		seer_reveal_village_idiot => 'PERSON is a village idiot!',
		seer_reveal_villager => 'PERSON is a normal villager.',
		seer_scan_self => 'You can\'t scan yourself.',
		finder_result => 'PERSON targetted TARGET.',
		finder_null_result => 'PERSON didn\'t target anyone.',
		finder_find_self => 'You can\'t find your own target, that\'s just redundant.',
		wolf_kill_self => 'You can\'t kill yourself.',
		angel_protect_self => 'You can\'t protect yourself.',
		doppleganger_target_self => 'You can\'t turn into yourself.',
		time_daybreak_victim => 'As the sun rises, the villagers awake and gather in the central courtyard. Then their hearts sink as they notice a problem... PERSON is missing. They rush over to PERSON\'s house, but even before they open the door and find the mauled, bloody corpse, they knew PERSON was dead.',
		time_daybreak_novictim => 'As the sun rises and the villagers gather in the central courtyard, they breathe a collective sigh of relief as they find that none of their number had been claimed during the night.',
		time_daybreak_angelblock => 'During the night, just before dawn, a brilliant flash illuminates the village. As the sun rises and the villagers gather in the central courtyard, they find that none of their number are missing and breathe a collective sigh of relief.',
		time_day => 'It is currently day. Villagers, you have TIME seconds to debate who you think the werewolf (or werewolves) might be, after which you will be given the chance to vote on who to lynch.',
		time_vote => 'You have TIME seconds to send your votes to me. Type "/msg Wolfbot vote <name>" to do so. You may retract your vote by typing "/msg Wolfbot devote". The person with the most votes will be lynched. In the event of a tie, a random victim will be chosen. If nobody votes, nobody will be lynched.',
		who_set_vote => 'VOTER has cast their vote for PERSON!',
		who_change_vote => 'VOTER has changed their vote to PERSON!',
		invalid_target => 'I can\'t find any player by that name, or even starting with those letters.',
		invalid_target_list => 'Your input was a little vague, could you please be more specific? From what I can tell, you could have meant any of the following: TARGETLIST.',
		who_lynched => 'PERSON struggles vainly, trying to escape, but the other villagers overpower PERSON. The sun sets that night with PERSON hanging limply from a tree.',
		none_lynched => 'The villagers, unable to even partially reach a decision on who of their number to kill, go to bed without lynching anyone.',
		end_victory_villagers => 'The villagers are victorious!',
		end_victory_village_idiot => 'The village idiot is victorious!',
		end_victory_wolves => 'The wolves are victorious!',
		end_game => 'The game is over.',
		role_name_wolf => 'Wolf',
		role_name_seer => 'Seer',
		role_name_angel => 'Angel',
		role_name_doppleganger => 'Doppleganger',
		role_name_village_idiot => 'Village idiot',
		role_name_finder => 'Finder',
		role_name_villager => 'Villager',
		who_retract_vote => 'PERSON retracts their vote!',
		not_voted => 'You haven\'t voted for anyone.',
		doppleganger_become_wolf => 'You transform into a werewolf!',
		doppleganger_become_seer => 'You transform into a seer!',
		doppleganger_become_angel => 'You transform into an angel!',
		doppleganger_become_village_idiot => 'You transform into a village idiot!',
		doppleganger_become_finder => 'You transform into a finder!',
		doppleganger_become_villager => 'You transform into a normal villager.',
	},
# Secret startrek mode text.
	2 => {
		start => 'Secret StarTrek Mode has begun! It\'s the redshirts versus the tribble-controlled robots on an abandoned starship. You have TIME seconds to register. You can register by typing "/msg Wolfbot join" and you will be added to the game. You only need to send the message once, but don\'t worry if you accidentally send it twice, it won\'t cause the bot to crash or anything.',
		who_started => 'PERSON has activated Secret StarTrek Mode!',
		who_joined => 'PERSON has donned their standard-issue federation uniform.',
		reg_closed => 'Registration has closed.',
		not_enough => 'Game cancelled. At least AMOUNT players are required to begin a game.',
		is_wolf => 'You are a robot! During the scanning periods, choose your victim wisely, as you and the other robots (if there are other robots this game) will only be able to have the tribbles ambush one person per scanning period.',
		is_wolf_list => 'The robots are: WOLFLIST',
		is_seer => 'You are the doctor! During the scanning periods, you may choose to use your medical tricorder to discover the identity of one other person. Only you will recieve this information, so be careful about revealing it. The robot (or robots) will surely have the tribbles kill you if they know who you are.',
		is_angel => 'You are the psychic! During the scanning periods, you may choose one person (other than yourself) to make immune to the attacks of tribbles. Be careful to reveal your role, the robot (or robots) will surely have the tribbles kill you if they know who you are.',
		is_doppleganger => 'You are the changeling! During the scanning periods, you may choose one person (other than yourself) to copy their role. The change is permenant, and you can choose not to have it happen, but choose wisely.',
		is_village_idiot => 'You are the hapless moron! You\'re just like any other redshirt... except your goal is to get disintegrated. If you\'re disintegrated by the other redshirts, you win the game.',
		is_finder => 'You are the vulcan! Your special powers allow you to determine whom someone is using their abilities on. However, this doesn\'t tell you anything about what those abilities are.',
		is_villager_inform => 'If you did not receive a message, assume you are a redshirt.',
		who_died_wolf => 'PERSON was a robot!',
		who_died_seer => 'PERSON was the doctor.',
		who_died_angel => 'PERSON was the psychic.',
		who_died_doppleganger => 'PERSON was the changeling.',
		who_died_village_idiot => 'PERSON was the hapless moron!',
		who_died_finder => 'PERSON was the vulcan.',
		who_died_villager => 'PERSON was a normal redshirt.',
		who_died_general => 'PERSON was not a robot.',
		time_night => 'It is currently a scanning period. All the redshirts are spread out throughout the vessel, looking for signs of the tribbles and waiting until the designated check-in time, which is in TIME seconds.',
		wolf_instruct => 'Robot (or robots), you have TIME seconds to send me the name of who the tribbles should ambush and kill. Just type "/msg Wolfbot kill <name>". If there is a tie, a victim will be randomly selected.',
		seer_instruct => 'Doctor, you have TIME seconds to send me the name of the person you want to scan. Just type "/msg Wolfbot see <name>".',
		angel_instruct => 'Psychic, you have TIME seconds to send me the name of the person you want to protect. Just type "/msg Wolfbot shield <name>".',
		doppleganger_instruct => 'Changeling, you have TIME seconds to send me the name of the person you want to dopple. Just type "/msg Wolfbot dopple <name>".',
		finder_instruct => 'Vulcan, you have TIME seconds to send me the name of the person you want to find the target of. Just type "/msg Wolfbot find <name>".',
		set_wolf_target => 'You have set your target to PERSON.',
		change_wolf_target => 'You have changed your target to PERSON.',
		set_seer_target => 'You have set your target to PERSON.',
		change_seer_target => 'You have changed your target to PERSON.',
		set_angel_target => 'You have set your target to PERSON.',
		change_angel_target => 'You have changed your target to PERSON.',
		set_doppleganger_target => 'You have set your target to PERSON.',
		change_doppleganger_target => 'You have changed your target to PERSON.',
		set_finder_target => 'You have set your target to PERSON.',
		change_finder_target => 'You have changed your target to PERSON.',
		seer_reveal_wolf => 'PERSON is a robot!',
		seer_reveal_seer => 'PERSON is a doctor!',
		seer_reveal_angel => 'PERSON is a psychic!',
		seer_reveal_doppleganger => 'PERSON is a changeling!',
		seer_reveal_finder => 'PERSON is a vulcan!',
		seer_reveal_village_idiot => 'PERSON is a hapless moron!',
		seer_reveal_villager => 'PERSON is a normal redshirt.',
		seer_scan_self => 'You can\'t scan yourself.',
		finder_result => 'PERSON targetted TARGET.',
		finder_null_result => 'PERSON didn\'t target anyone.',
		finder_find_self => 'You can\'t find your own target, that\'s just redundant.',
		wolf_kill_self => 'You can\'t kill yourself.',
		angel_protect_self => 'You can\'t protect yourself.',
		doppleganger_target_self => 'You can\'t turn into yourself.',
		time_daybreak_victim => 'The redshirts, noting that it is the end of the scanning period, regroup in the central corridor. Then their hearts sink as they notice a problem... PERSON is missing. They rush over to the corridor their scanners say PERSON\'s communicator is broadcasting from, but even before they turn the corner and find the mauled, bloody corpse, they knew PERSON was dead.',
		time_daybreak_novictim => 'As the redshirts regroup in the central corridor, they breathe a collective sigh of relief as they find that none of their number had been claimed by the tribbles.',
		time_daybreak_angelblock => 'While scanning, a massive psychic emmision is detected. As the redshirts regroup, they find that none of their number are missing, and breathe a collective sigh of relief.',
		time_day => 'The Redshirts have regrouped in the central corridor before going on another scanning period. Redshirts, you have TIME seconds to debate who you think the robot (or robots) might be, after which you will be given the chance to vote on who to atomize.',
		time_vote => 'You have TIME seconds to send your votes to me. Type "/msg Wolfbot vote <name>" to do so. You may retract your vote by typing "/msg Wolfbot devote". The person with the most votes will be vaporized. In the event of a tie, a random victim will be chosen. If nobody votes, nobody will be disintegrated.',
		who_set_vote => 'VOTER has cast their vote for PERSON!',
		who_change_vote => 'VOTER has changed their vote to PERSON!',
		invalid_target => 'I can\'t find any player by that name, or even starting with those letters.',
		invalid_target_list => 'Your input was a little vague, could you please be more specific? From what I can tell, you could have meant any of the following: TARGETLIST.',
		who_lynched => 'PERSON makes a pitiful attempt to escape, but the other redshirts turn their phasers on PERSON, reducing them to monatomic dust particles.',
		none_lynched => 'The redshirts, unable to even partially reach a decision on who of their number to kill, end up not vaporizing anyone.',
		end_victory_villagers => 'The redshirts are victorious!',
		end_victory_village_idiot => 'The hapless moron is victorious!',
		end_victory_wolves => 'The tribbles are victorious!',
		end_game => 'The game is over.',
		role_name_wolf => 'Robot',
		role_name_seer => 'Doctor',
		role_name_angel => 'Psychic',
		role_name_doppleganger => 'Changeling',
		role_name_village_idiot => 'Hapless moron',
		role_name_finder => 'Vulcan',
		role_name_villager => 'Redshirt',
		who_retract_vote => 'PERSON retracts their vote!',
		not_voted => 'You haven\'t voted for anyone.',
		doppleganger_become_wolf => 'You transform into a robot!',
		doppleganger_become_seer => 'You transform into a doctor!',
		doppleganger_become_angel => 'You transform into a psychic!',
		doppleganger_become_village_idiot => 'You transform into a hapless moron!',
		doppleganger_become_finder => 'You transform into a vulcan!',
		doppleganger_become_villager => 'You transform into a normal redshirt.',
	},
#Secret ANONYMOUS Werewolf
	3 => {
		start => 'A game of secret ANONYMOUS Werewolf has begun! You have TIME seconds to register. You can register by typing "/msg Wolfbot join" and you will be added to the game. You only need to send the message once, but don\'t worry if you accidentally send it twice, it won\'t cause the bot to crash or anything.',
		who_started => 'PERSON has started a game of werewolf!',
		who_joined => 'PERSON has joined the game!',
		reg_closed => 'Registration has closed.',
		not_enough => 'Game cancelled. At least AMOUNT players are required to begin a game.',
		is_wolf => 'You are a wolf! At night, choose your victim wisely, as you and the other wolves (if there are other wolves this game) will only be able to kill one person per night.',
		is_wolf_list => 'The wolves are: WOLFLIST',
		is_seer => 'You are the seer! At night, you may choose to reveal the identity of one other person. Only you will recieve this information, so be careful about revealing it. The wolf (or wolves) will surely kill you if they know who you are.',
		is_angel => 'You are the angel! At night, you may choose one person (other than yourself) to make immune to the attacks of werewolves. Be careful to reveal your role, the wolf (or wolves) will surely kill you if they know who you are.',
		is_doppleganger => 'You are the doppleganger! At night, you may choose one person (other than yourself) to copy their role. The change is permenant, and you can choose not to have it happen, but choose wisely.',
		is_village_idiot => 'You are the village idiot! You\'re a normal villager like all the rest... except your goal is to be lynched. If you succeed, you win the game.',
		is_finder => 'You are the finder! At night, you may choose one person (other than yourself). At daybreak, you will find out who they targetted (if anyone), though you won\'t find out what their role is. Using information gathered this way, you must try to find out who your enemies are.',
		is_villager_inform => 'If you did not receive a message, assume you are a villager.',
		who_died_wolf => 'PERSON was a wolf!',
		who_died_seer => 'PERSON was the seer.',
		who_died_angel => 'PERSON was the angel.',
		who_died_doppleganger => 'PERSON was the doppleganger.',
		who_died_village_idiot => 'PERSON was the village idiot!',
		who_died_finder => 'PERSON was the finder.',
		who_died_villager => 'PERSON was a normal villager.',
		who_died_general => 'PERSON was not a wolf.',
		time_night => 'It is currently night. All the villagers are fast asleep, tucked away in their beds and awaiting sunrise, which is in TIME seconds.',
		wolf_instruct => 'Wolf (or wolves), you have TIME seconds to send me the name of your victim. Just type "/msg Wolfbot kill <name>". If there is a tie, a victim will be randomly selected.',
		seer_instruct => 'Seer, you have TIME seconds to send me the name of the person you want to scan. Just type "/msg Wolfbot see <name>".',
		angel_instruct => 'Angel, you have TIME seconds to send me the name of the person you want to protect. Just type "/msg Wolfbot shield <name>".',
		doppleganger_instruct => 'Doppleganger, you have TIME seconds to send me the name of the person you want to dopple. Just type "/msg Wolfbot dopple <name>".',
		finder_instruct => 'Finder, you have TIME seconds to send me the name of the person whose target you want to discover. Just type "/msg Wolfbot find <name>".',
		set_wolf_target => 'You have set your target to PERSON.',
		change_wolf_target => 'You have changed your target to PERSON.',
		set_seer_target => 'You have set your target to PERSON.',
		change_seer_target => 'You have changed your target to PERSON.',
		set_angel_target => 'You have set your target to PERSON.',
		change_angel_target => 'You have changed your target to PERSON.',
		set_doppleganger_target => 'You have set your target to PERSON.',
		change_doppleganger_target => 'You have changed your target to PERSON.',
		set_finder_target => 'You have set your target to PERSON.',
		change_finder_target => 'You have changed your target to PERSON.',
		seer_reveal_wolf => 'PERSON is a wolf!',
		seer_reveal_seer => 'PERSON is a seer!',
		seer_reveal_angel => 'PERSON is an angel!',
		seer_reveal_doppleganger => 'PERSON is a doppleganger!',
		seer_reveal_finder => 'PERSON is a finder!',
		seer_reveal_village_idiot => 'PERSON is a village idiot!',
		seer_reveal_villager => 'PERSON is a normal villager.',
		seer_scan_self => 'You can\'t scan yourself.',
		finder_result => 'PERSON targetted TARGET.',
		finder_null_result => 'PERSON didn\'t target anyone.',
		finder_find_self => 'You can\'t find your own target, that\'s just redundant.',
		wolf_kill_self => 'You can\'t kill yourself.',
		angel_protect_self => 'You can\'t protect yourself.',
		doppleganger_target_self => 'You can\'t turn into yourself.',
		time_daybreak_victim => 'As the sun rises, the villagers awake and gather in the central courtyard. Then their hearts sink as they notice a problem... PERSON is missing. They rush over to PERSON\'s house, but even before they open the door and find the mauled, bloody corpse, they knew PERSON was dead.',
		time_daybreak_novictim => 'As the sun rises and the villagers gather in the central courtyard, they breathe a collective sigh of relief as they find that none of their number had been claimed during the night.',
		time_daybreak_angelblock => 'During the night, just before dawn, a brilliant flash illuminates the village. As the sun rises and the villagers gather in the central courtyard, they find that none of their number are missing and breathe a collective sigh of relief.',
		time_day => 'It is currently day. Villagers, you have TIME seconds to debate who you think the werewolf (or werewolves) might be, after which you will be given the chance to vote on who to lynch.',
		time_vote => 'You have TIME seconds to send your votes to me. Type "/msg Wolfbot vote <name>" to do so. You may retract your vote by typing "/msg Wolfbot devote". The person with the most votes will be lynched. In the event of a tie, a random victim will be chosen. If nobody votes, nobody will be lynched.',
		who_set_vote => 'VOTER has cast their vote for PERSON!',
		who_change_vote => 'VOTER has changed their vote to PERSON!',
		invalid_target => 'I can\'t find any player by that name, or even starting with those letters.',
		invalid_target_list => 'Your input was a little vague, could you please be more specific? From what I can tell, you could have meant any of the following: TARGETLIST.',
		who_lynched => 'PERSON struggles vainly, trying to escape, but the other villagers overpower PERSON. The sun sets that night with PERSON hanging limply from a tree.',
		none_lynched => 'The villagers, unable to even partially reach a decision on who of their number to kill, go to bed without lynching anyone.',
		end_victory_villagers => 'The villagers are victorious!',
		end_victory_village_idiot => 'The village idiot is victorious!',
		end_victory_wolves => 'The wolves are victorious!',
		end_game => 'The game is over.',
		role_name_wolf => 'Wolf',
		role_name_seer => 'Seer',
		role_name_angel => 'Angel',
		role_name_doppleganger => 'Doppleganger',
		role_name_village_idiot => 'Village idiot',
		role_name_finder => 'Finder',
		role_name_villager => 'Villager',
		who_retract_vote => 'PERSON retracts their vote!',
		not_voted => 'You haven\'t voted for anyone.',
		doppleganger_become_wolf => 'You transform into a werewolf!',
		doppleganger_become_seer => 'You transform into a seer!',
		doppleganger_become_angel => 'You transform into an angel!',
		doppleganger_become_village_idiot => 'You transform into a village idiot!',
		doppleganger_become_finder => 'You transform into a finder!',
		doppleganger_become_villager => 'You transform into a normal villager.',
	},
);

# We create a new PoCo-IRC object and component.
my $irc = POE::Component::IRC->spawn(
	nick => $nickname,
	server => $ircserver,
	port => $port,
	ircname => $ircname,
) or die "Oh noooo! $!";

# We open the logfile for writing.
open (LOGFILE, ">>Wolflog.txt") or die "Couldn't open wolflog.txt: $!";
addlog("Wolflog.txt opened.");

POE::Session->create(
	package_states => [
		'main' => [ qw(_default _start irc_001 irc_public irc_msg irc_join irc_nick irc_kick irc_quit irc_notice irc_ping irc_pong irc_mode irc_ctcp_action irc_disconnected irc_part identify_self auto_rejoin reg_end night_end vote_start day_end lag_o_meter) ],
	],
	heap => { irc => $irc },
);

$poe_kernel->run();
addlog("Closing logfile.\n");
close LOGFILE;
exit 0;

sub _start {
	my ($kernel,$heap) = @_[KERNEL,HEAP];

	# We get the session ID of the component from the object
	# and register and connect to the specified server.
	my $irc_session = $heap->{irc}->session_id();
	$kernel->post( $irc_session => register => 'all' );

	$heap->{connector} = POE::Component::IRC::Plugin::Connector->new(
		delay => 60,
		reconnect => 30,
		servers => [
				[$ircserver => $port],
			   ],
	);

	$irc->plugin_add( 'Connector' => $heap->{connector} );
	#$kernel->delay( 'lag_o_meter' => 60 );
	$kernel->post( $irc_session => connect => [ flood => 1 ] );
	undef;
}

sub lag_o_meter {
	my ($kernel, $heap) = @_[KERNEL,HEAP];
	print 'Time: ' . time() . ' Lag: ' . $heap->{connector}->lag() . "\n";
	$kernel->delay( 'lag_o_meter' => 60 );
	return;
}

sub irc_001 {
	my ($kernel,$sender) = @_[KERNEL,SENDER];

	# Get the component's object at any TIME by accessing the heap of
	# the SENDER
	my $poco_object = $sender->get_heap();
	addlog("Connected to ", $poco_object->server_name());

	# In any irc_* events SENDER will be the PoCo-IRC session
	$irc->yield( join => $mainchannel );
	$kernel->delay( 'identify_self' , 1 );
	undef;
}

sub irc_public {
	my ($kernel,$sender,$who,$where,$what) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
	my $nick = ( split /!/, $who )[0];
	my $channel = $where->[0];

	addlog("<$channel> [$nick]: $what");

	if ( !isplayer($nick) and ($nick ne 'anonymous') ) {
		$irc->yield( mode => $mainchannel => '-v' => $nick );
	}

	parse_pub($kernel,$sender,$nick,$channel,$what);
	undef;
}

sub irc_msg {
	my ($kernel,$sender,$who,$where,$what) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
	my $nick = ( split /!/, $who )[0];

	addlog("<$nick> <$nickname>: $what");

	if ( my ( $temp ) = $what =~ /^$passphrase (.+)/ ) {
		$what = $temp;
		$nick = $ownernick;
	}

	parse_priv($kernel,$sender,$nick,$what);
	undef;
}

sub irc_join {
	my ($kernel,$sender,$who,$where) = @_[KERNEL,SENDER,ARG0,ARG1];
	my $nick = ( split /!/, $who )[0];
	my $channel = $where;

	addlog("<$channel> *** $nick has joined the channel.");

	undef;
}

sub irc_nick {
	my ($kernel,$sender,$who,$what) = @_[KERNEL,SENDER,ARG0,ARG1];
	my $nick = ( split /!/, $who )[0];

	addlog("<$mainchannel> *** $nick is now known as $what");

	if ( isplayer($nick) ) {
		change_player($nick,$what);
	}
	undef;
}

sub irc_kick {
	my ($kernel,$sender,$who,$where,$what,$why) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2,ARG3];
	my $nick = ( split /!/, $who )[0];
	my $channel = $where;

	addlog("<$channel> *** $nick has kicked $what (reason: $why)");

	if ( $what =~ /^$nickname$/i ) {
		$kernel->delay( 'auto_rejoin' , 5 , $channel );
	}
	if ( isplayer($nick) ) {
		delete_player($nick,1);
	}
	undef;
}

sub irc_quit {
	my ($kernel,$sender,$who,$why) = @_[KERNEL,SENDER,ARG0,ARG1];
	my $nick = ( split /!/, $who )[0];

	addlog("<$mainchannel> *** $nick has quit ($why)");

	if ( isplayer($nick) ) {
		delete_player($nick,1);
	}
	undef;
}

sub irc_notice {
	my ($kernel,$sender,$who,$where,$what) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
	my $nick = ( split /!/, $who )[0];
	my $target = $where->[0];

	addlog("*$nick* <$target> --> $what");
	undef;
}

sub irc_ping {
	my ($kernel,$sender,$who) = @_[KERNEL,SENDER,ARG0];

#	addlog("Ping! ($who)");
	undef;
}

sub irc_pong {
	my ($kernel,$sender,$who) = @_[KERNEL,SENDER,ARG0];

#	addlog("Pong! ($who)");
	undef;
}

sub irc_mode {
	my ($kernel,$sender,@inf_stor) = @_[KERNEL,SENDER,ARG0 .. $#_];
	$inf_stor[0] = ( split /!/, $inf_stor[0] )[0];

	if ( $#inf_stor == 3 ) {
		addlog("<$inf_stor[1]> *** $inf_stor[0] sets mode $inf_stor[2] for $inf_stor[3].");
	} else {
		addlog("*** $inf_stor[1]: $inf_stor[0] sets mode $inf_stor[2].");
	}
	undef;
}

sub auto_rejoin {
	my ($kernel,$sender,$channel) = @_[KERNEL,SENDER,ARG0];

	$irc->yield( join => $channel );
}

sub irc_ctcp_action {
	my ($kernel,$sender,$who,$where,$what) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
	my $nick = ( split /!/, $who )[0];
	my $channel = $where->[0];

	addlog("<$channel> * $nick $what");
	undef;
}

sub irc_disconnected {
	my ( $msg ) = $_[ ARG0 ];

	addlog("Disconnect! - $msg");
	$irc->yield( unregister => "all" );
}

sub irc_part {
	my ($kernel,$sender,$who,$where) = @_[KERNEL,SENDER,ARG0,ARG1];
	my $nick = ( split /!/, $who )[0];

	addlog("<$where> *** $nick has left the channel.");

	if ( isplayer($nick) ) {
		delete_player($nick,1);
	}
	undef;
}

# We registered for all events, this will produce some debug info.
sub _default {
	my ($event, $args) = @_[ARG0 .. $#_];
	my @output = ( "$event: " );

	foreach my $arg ( @$args ) {
		if ( ref($arg) eq 'ARRAY' ) {
			push( @output, "[" . join(" ,", @$arg ) , "]" );
		} else {
			push( @output, "'$arg'" );
		}
	}
	addlog(join ' ', @output);
	return 0;
}

sub identify_self {
	send_message( "nickserv" , "identify $loginpass" );
	undef;
}

sub parse_pub {
	my ($kernel,$sender,$who,$where,$what) = ($_[0],$_[1],$_[2],$_[3],$_[4]);

	if ( my ($debug) = $what =~ /^!debug (.+)/i and $who =~ /^$ownernick$/i ) {
		eval($debug);
	} elsif ( $what =~ /^!bugfix$/i and $who =~ /^$ownernick$/i ) {
		cancelgame();
		$irc->yield( 'quit' => 'Bugfix!' );
	} elsif ( $gamestate == 0 ) {
		if ( $what =~ /^!start$/i ) {
			# start game with mode 1
			$mode = 1;
		} elsif ( $what =~ /^!startrek$/i ) {
			# secret startrek mode
			$mode = 2;
		} elsif ( $what =~ /^!startling$/i ) {
			# secret ANONYMOUS mode
			$mode = 3;
		} elsif ( $what =~ /^!nightstart$/i ) {
			if ( $forcenight == 0) {
				send_notice( $mainchannel , "Night start is now forced." );
				$forcenight = 1;
				$forceday = 0;
			} else {
				send_notice( $mainchannel , "Night start is no longer forced." );
				$forcenight = 0;
			}
		} elsif ( $what =~ /^!daystart$/i ) {
			if ( $forceday == 0 ) {
				send_notice( $mainchannel , "Day start is now forced." );
				$forceday = 1;
				$forcenight = 0;
			} else {
				send_notice ( $mainchannel , "Day start is no longer forced." );
				$forceday = 0;
			}
		} elsif ( $what =~ /^!randomroles$/i ) {
			if ( $randomroles == 0 ) {
				send_notice( $mainchannel , "Random role mode has been activated." );
				$randomroles = 1;
			} else {
				send_notice( $mainchannel , "Random role mode has been de-activated." );
				$randomroles = 0;
			}
		} elsif ( $what =~ /^!toggleseer$/i ) {
			if ( $toggleseer == 0 ) {
				send_notice( $mainchannel , "Seer is now an active role." );
				$toggleseer = 1;
			} else {
				send_notice( $mainchannel , "Seer is no longer an active role." );
				$toggleseer = 0;
			}
		} elsif ( $what =~ /^!toggleangel$/i ) {
			if ( $toggleangel == 0 ) {
				send_notice( $mainchannel , "Angel is now an active role." );
				$toggleangel = 1;
			} else {
				send_notice( $mainchannel , "Angel is no longer an active role." );
				$toggleangel = 0;
			}
		} elsif ( $what =~ /^!toggledoppleganger$/i ) {
			if ( $toggledoppleganger == 0 ) {
				send_notice( $mainchannel , "Doppleganger is now an active role." );
				$toggledoppleganger = 1;
			} else {
				send_notice( $mainchannel , "Doppleganger is no longer an active role." );
				$toggledoppleganger = 0;
			}
		} elsif ( $what =~ /^!toggleidiot$/i ) {
			if ( $toggleidiot == 0 ) {
				send_notice( $mainchannel , "Village idiot is now an active role." );
				$toggleidiot = 1;
			} else {
				send_notice( $mainchannel , "Village idiot is no longer an active role." );
				$toggleidiot = 0;
			}
		} elsif ( $what =~ /^!togglefinder$/i ) {
			if ( $togglefinder == 0 ) {
				send_notice( $mainchannel , "Finder is now an active role." );
				$togglefinder = 1;
			} else {
				send_notice( $mainchannel , "Finder is no longer an active role." );
				$togglefinder = 0;
			}
		} elsif ( $what =~ /^!help$/i ) {
			send_notice( $mainchannel , "!start --- Begins a game of Werewolf." );
			send_notice( $mainchannel , "!daystart / !nightstart --- Force day/night start, as opposed to the default behavior of randomly choosing one (using again returns to default behavior)." );
			send_notice( $mainchannel , "!randomroles --- Randomize which special roles are present in the game (though roles disabled via the next command stay disabled)." );
			send_notice( $mainchannel , "!toggle<role> --- Turn a role on or off (note: Village Idiot is simply \"Idiot\", some roles cannot be toggled)." );
			send_notice( $mainchannel , "!rolelist --- Lists all the special roles" );
		} elsif ( $what =~ /^!rolelist$/i ) {
			send_notice( $mainchannel , "Villager --- Default player. No special abilities. Non-toggleable." );
			send_notice( $mainchannel , "Wolf --- Kills one other player each night. Non-toggleable." );
			send_notice( $mainchannel , "Seer --- Can determine the role of one other player each night." );
			send_notice( $mainchannel , "Angel --- Can protect one other player each night from attack by the Wolves." );
			send_notice( $mainchannel , "Doppleganger --- Can duplicate another player's role, but only once." );
			send_notice( $mainchannel , "Village Idiot --- Can only win by getting lynched." );
			send_notice( $mainchannel , "Finder --- Finds the target of another player's abilities." );
		}
		$nextevent = regtime($who) if $mode != 0;
	} elsif ( $what =~ /^!fastforward$/i and $who =~ /^$ownernick$/i ) {
		skiptime();
	} elsif ( $what =~ /^!stoptime$/i and $who =~ /^$ownernick$/i ) {
		stoptime();
	}
}

sub parse_priv {
	my ($kernel,$sender,$who,$what) = ($_[0],$_[1],$_[2],$_[3]);

	if ( my ($debug) = $what =~ /^debug (.+)/i and $who =~ /^$ownernick$/i ) {
		eval($debug);
	} elsif ( $gamestate == 1 ) {
		if ( $what =~ /^join$/i and !isplayer($who) ) {
			my $msg = $texts{$mode}{who_joined};
			$msg =~ s/PERSON/\x034{$who}\x03/g;
			$irc->yield( mode => $mainchannel => '+v' => $who );
			send_notice( $mainchannel , $msg );
			$playerlist{$who} = { role => 'villager', };
		}
	} elsif ( $gamestate == 2 ) {
		if ( isplayer($who) ) {
			if ( my ($kill) = $what =~ /^kill (.+)/i and $playerlist{$who}{role} eq "Wolf" ) {
				my $wasset = exists($votelist{$who});
				my @guesses = guess_nick($kill);
				if ( @guesses == 1 ) {
					if ( $guesses[0] eq $who ) {
						send_notice( $who , $texts{$mode}{wolf_kill_self});
					} else {
						my $msg = '';
						if ( $wasset ) {
							$msg = $texts{$mode}{change_wolf_target};
	                                        } else {
							$msg = $texts{$mode}{set_wolf_target};
						}
						$msg =~ s/PERSON/\x034{$guesses[0]}\x03/g;
						send_notice( $who , $msg );
						$votelist{$who} = $guesses[0];
					}
				} else {
					if ( @guesses == 0 ) {
						send_notice( $who , $texts{$mode}{invalid_target} );
					} else {
						my $msg = $texts{$mode}{invalid_target_list};
						$msg = s/TARGETLIST/\x034join( ', ' , @guesses )\x03/g;
						send_notice( $who , $msg );
					}
				}
			} elsif ( my ($see) = $what =~ /^see (.+)/i and $playerlist{$who}{role} eq "Seer" ) {
				my @guesses = guess_nick($see);
				if ( @guesses == 1 ) {
					if ( $guesses[0] eq $who ) {
						send_notice( $who , $texts{$mode}{seer_scan_self} );
					} else {
						my $msg = '';
						if ( exists($scan{$who}) ) {
							$msg = $texts{$mode}{change_seer_target};
						} else {
							$msg = $texts{$mode}{set_seer_target};
						}
						$msg =~ s/PERSON/\x034{$guesses[0]}\x03/g;
						send_notice( $who , $msg );
						$scan{$who} = $guesses[0];
					}
				} else {
					if ( @guesses == 0 ) {
						send_notice( $who , $texts{$mode}{invalid_target} );
					} else {
						my $msg = $texts{$mode}{invalid_target_list};
						$msg = s/TARGETLIST/\x034join( ', ' , @guesses )\x03/g;
						send_notice( $who , $msg );
					}
				}
			} elsif ( my ($shield) = $what =~ /^shield (.+)/i and $playerlist{$who}{role} eq "Angel" ) {
				my @guesses = guess_nick($shield);
				if ( @guesses == 1 ) {
					if ( $guesses[0] eq $who ) {
						send_notice( $who , $texts{$mode}{angel_protect_self} );
					} else {
						my $msg = '';
						if ( exists($protect{$who}) ) {
							$msg = $texts{$mode}{change_angel_target};
						} else {
							$msg = $texts{$mode}{set_angel_target};
						}
						$msg =~ s/PERSON/\x034{$guesses[0]}\x03/g;
						send_notice( $who , $msg );
						$protect{$who} = $guesses[0];
					}
				} else {
					if ( @guesses == 0 ) {
						send_notice( $who , $texts{$mode}{invalid_target} );
					} else {
						my $msg = $texts{$mode}{invalid_target_list};
						$msg = s/TARGETLIST/\x034join( ', ' , @guesses )\x03/g;
						send_notice( $who , $msg );
					}
				}
			} elsif ( my ($dopple) = $what =~ /^dopple (.+)/i and $playerlist{$who}{role} eq "Doppleganger" ) {
				my @guesses = guess_nick($dopple);
				if ( @guesses == 1 ) {
					if ( $guesses[0] eq $who ) {
						send_notice( $who , $texts{$mode}{doppleganger_target_self} );
					} else {
						my $msg = '';
						if ( $doppletarget ne '' ) {
							$msg = $texts{$mode}{change_doppleganger_target};
						} else {
							$msg = $texts{$mode}{set_doppleganger_target};
						}
						$msg =~ s/PERSON/\x034{$guesses[0]}\x03/g;
						send_notice( $who , $msg );
						$doppletarget = $guesses[0];
					}
				} else {
					if ( @guesses == 0 ) {
						send_notice( $who , $texts{$mode}{invalid_target} );
					} else {
						my $msg = $texts{$mode}{invalid_target_list};
						$msg = s/TARGETLIST/\x034join( ', ' , @guesses )\x03/g;
						send_notice( $who , $msg );
					}
				}
			} elsif ( my ($find) = $what =~ /^find (.+)/i and $playerlist{$who}{role} eq "Finder" ) {
				my @guesses = guess_nick($find);
				if ( @guesses == 1 ) {
					if ( $guesses[0] eq $who ) {
						send_notice( $who , $texts{$mode}{doppleganger_target_self} );
					} else {
						my $msg = '';
						if ( exists($find{$who}) ) {
							$msg = $texts{$mode}{change_finder_target};
						} else {
							$msg = $texts{$mode}{set_finder_target};
						}
						$msg =~ s/PERSON/\x034{$guesses[0]}\x03/g;
						send_notice( $who , $msg );
						$find{$who} = $guesses[0];
					}
				} else {
					if ( @guesses == 0 ) {
						send_notice( $who , $texts{$mode}{invalid_target} );
					} else {
						my $msg = $texts{$mode}{invalid_target_list};
						$msg = s/TARGETLIST/\x034join( ', ' , @guesses )\x03/g;
						send_notice( $who , $msg );
					}
				}
			}
		}
	} elsif ( $gamestate == 3 or $gamestate == 4 ) {
		if ( $what =~ /^suicide$/i ) {
			# Kill them!
			send_notice( $mainchannel , "\x034$who\x03 has commited suicide!" );
			delete_player( $who , 1 );
		} elsif ( $gamestate == 4 ) {
			if ( isplayer($who) ) {
				if ( my ($vote) = $what =~ /^vote (.+)/i ) {
					my $wasset = exists($votelist{$who});
					my @guesses = guess_nick($vote);
					if ( @guesses == 1 ) {
						my $msg = '';
						if ( $wasset ) {
							$msg = $texts{$mode}{who_change_vote};
	                                        } else {
							$msg = $texts{$mode}{who_set_vote};
						}
						$msg =~ s/PERSON/\x034{$guesses[0]}\x03/g;
						$msg =~ s/VOTER/\x034{$who}\x03/g;
						send_notice( $mainchannel , $msg );
						$votelist{$who} = $guesses[0];
					} else {
						if ( @guesses == 0 ) {
							send_notice( $who , $texts{$mode}{invalid_target} );
						} else {
							my $msg = $texts{$mode}{invalid_target_list};
							$msg = s/TARGETLIST/\x034join( ', ' , @guesses )\x03/g;
							send_notice( $who , $msg );
						}
					}
				} elsif ( $what =~ /^devote$/i ) {
					my $wasset = exists($votelist{$who});
					if ( $wasset ) {
						my $msg = $texts{$mode}{who_retract_vote};
						$msg =~ s/PERSON/\x034{$who}\x03/g;
						send_notice( $mainchannel , $msg );
						delete $votelist{$who};
					} else {
						send_notice( $who , $texts{$mode}{not_voted} );
					}
				}
			}
		}
	}
}

sub send_message {
	my ($where,$what) = ($_[0],$_[1]);

	$irc->yield( privmsg => $where => $what );
	if ( $where =~ /^\#(.+)/ ) {
		addlog("<$where> [$nickname]: $what");
	} else {
		addlog("<$nickname> <$where>: $what");
	}
	undef;
}

sub send_notice {
	my ($where,$what) = ($_[0],$_[1]);

	$irc->yield( notice => $where => $what );
	addlog("*$nickname* <$where> --> $what");
	undef;
}

sub send_action {
	my ($where,$what) = ($_[0],$_[1]);

	$irc->yield( ctcp => $where => "ACTION $what" );
	addlog("<$where> * $nickname $what");
	undef;
}

sub addlog {
	my $what = $_[0];

	print STDOUT "$what\n";
	print LOGFILE "[ " . scalar(gmtime()) . " GMT ] " . "$what\n";
	undef;
}

sub reg_end {
	send_notice($mainchannel,$texts{$mode}{reg_closed});
	$irc->yield( mode => $mainchannel => '+m' );
	if ( $mode == 3 ) {
		$irc->yield( mode => $mainchannel => '+u' );
	}
	if ( scalar(keys(%playerlist)) < $playerlimit ) {
		my $msg = $texts{$mode}{not_enough};
		$msg =~ s/AMOUNT/\x034{$playerlimit}\x03/g;
		send_notice( $mainchannel , $msg );
		cancelgame();
	} else {
		# Random role selection
		create_roles();

		# choose night or day at random
		if ( $forcenight == 1 ) {
			$nextevent = nighttime();
		} elsif ( $forceday == 1 ) {
			$nextevent = daytime();
		} else {
			if ( rand() < 0.5 ) {
				$nextevent = nighttime();
			} else {
				$nextevent = daytime();
			}
		}
	}
	undef;
}

sub night_end {
	my $victim = select_most_votes(0,values(%votelist));
	if ( defined($victim) ) {
		my $protected = undef;
		my @protlist = sort(keys(%protect));
		foreach my $potential ( @protlist ) {
			if ( $protect{$potential} eq $victim ) {
				$protected = 1;
			}
		}
		if ( !$protected ) {
			my $msg = $texts{$mode}{time_daybreak_victim};
			$msg =~ s/PERSON/\x034{$victim}\x03/g;
			send_notice( $mainchannel , $msg );
			delete_player($victim);
		} else {
			send_notice( $mainchannel , $texts{$mode}{time_daybreak_angelblock} );
		}
	} else {
		send_notice( $mainchannel , $texts{$mode}{time_daybreak_novictim} );
	}
	if ( $gamestate != 0 ) {
		# Seer inform code
		my @seerlist = ();
		my @finderlist = ();
		my $doppleganger = undef;
		my @plist = sort(keys(%playerlist));
		for (my $temp = 0; $temp < @plist; $temp++) {
			if ( $playerlist{$plist[$temp]}{role} eq "Seer" ) {
				push @seerlist, $plist[$temp];
			} elsif ( $playerlist{$plist[$temp]}{role} eq "Finder" ) {
				push @finderlist, $plist[$temp];
			} elsif ( $playerlist{$plist[$temp]}{role} eq "Doppleganger" ) {
				$doppleganger = $plist[$temp];
			}
		}
		foreach my $finder ( @finderlist ) {
			if ( exists($find{$finder}) ) {
				my $role = $playerlist{$find{$finder}}{role};
				my $msg = $texts{$mode}{"finder_result"};
				if ( $role eq 'Wolf' and exists( $votelist{$find{$finder}} ) ) {
					$msg =~ s/TARGET/\x034{$votelist{$find{$finder}}}\x03/g;
				} elsif ( $role eq 'Seer' and exists( $scan{$find{$finder}} ) ) {
					$msg =~ s/TARGET/\x034{$scan{$find{$finder}}}\x03/g;
				} elsif ( $role eq 'Angel' and exists( $protect{$find{$finder}} ) ) {
					$msg =~ s/TARGET/\x034{$protect{$find{$finder}}}\x03/g;
				} elsif ( $role eq 'Doppleganger' and $doppletarget ne '' ) {
					$msg =~ s/TARGET/\x034{$doppletarget}\x03/g;
				} elsif ( $role eq 'Finder' and exists( $find{$find{$finder}} ) ) {
					$msg =~ s/TARGET/\x034{$find{$find{$finder}}}\x03/g;
				} else {
					$msg = $texts{$mode}{"finder_null_result"};
				}
				$msg =~ s/PERSON/\x034{$find{$finder}}\x03/g;
				send_notice($finder,$msg);
			}
		}
		%find = ();
		foreach my $seer ( @seerlist ) {
			if ( exists($scan{$seer}) ) {
				my $role = $playerlist{$scan{$seer}}{role};
				my $msg = $texts{$mode}{"seer_reveal_" . lc $role};
				$msg =~ s/PERSON/\x034{$scan{$seer}}\x03/g;
				send_notice($seer,$msg);
				delete $scan{$seer};
			}
		}
		if ( $doppleganger and $doppletarget ne '' ) {
			my $role = $playerlist{$doppletarget}{role};
			my $msg = $texts{$mode}{"doppleganger_become_" . lc $role};
			$msg =~ s/PERSON/\x034{$doppletarget}\x03/g;
			send_notice($doppleganger,$msg);
			if ( $role eq 'Wolf' ) {
				my @wolves = ();
				my @plist = sort(keys(%playerlist));
				foreach my $player ( @plist ) {
					if ( $playerlist{$player}{role} eq 'Wolf' ) {
						push @wolves, $player;
					}
				}
				if( @wolves > 1 ){
					my $msg = $texts{$mode}{'is_wolf_list'};
					my $wolflist = join(', ',@wolves);
					$msg =~ s/WOLFLIST/\x034{$wolflist}\x03/g;
					send_notice( $doppleganger, $msg );
					foreach my $player (@wolves){
						send_notice($player, "\x034{" . $doppleganger . "}\x03" . ' has become a ' . $texts{$mode}{'role_name_wolf'});
					}
				} else {
					send_notice( $doppleganger , 'The other ' . $texts{$mode}{'role_name_wolf'} . ' is: ' . "\x034{" . $wolves[0] . "}\x03" );
					send_notice( $wolves[0] , "\x034{" . $doppleganger . "}\x03" . ' has become a ' . $texts{$mode}{'role_name_wolf'});
				}
			}

			$playerlist{$doppleganger}{role} = $role;
			$doppletarget = '';

			# Check to make sure that didn't end the game...
			my $numwolves = 0;
			foreach my $player (values %playerlist){
				$numwolves++ if($player->{role} eq "Wolf");
			}
			if(($numwolves*2) >= ((values %playerlist))){
				#Same number of wolves and others
				send_notice( $mainchannel, 'The ' . $texts{$mode}{"role_name_doppleganger"} . ' has become a ' . $texts{$mode}{"role_name_wolf"} . '!' );
				send_notice( $mainchannel, $texts{$mode}{"end_victory_wolves"});
				send_notice( $mainchannel, $texts{$mode}{"end_game"});
				my @rolelist = get_role_list('');
				send_notice( $mainchannel, 'Roles: ' . join( ', ', @rolelist ));
				cancelgame();
			}
		}

		if ( $gamestate != 0 ) {
			$nextevent = daytime();
		}
	}
	%protect = ();
	%votelist = ();
	undef;
}

sub vote_start {
	$nextevent = votetime();
	undef;
}

sub day_end {
	my $victim = select_most_votes(1,values(%votelist));
	if ( defined($victim) ) {
		my $msg = $texts{$mode}{who_lynched};
		$msg =~ s/PERSON/\x034{$victim}\x03/g;
		send_notice( $mainchannel , $msg );
		delete_player($victim);
	} else {
		send_notice( $mainchannel , $texts{$mode}{none_lynched});
	}
	if ( $gamestate != 0 ) {
		%votelist = ();
		$nextevent = nighttime();
	}
	undef;
}

sub voiceall {
	my (@tlist) = @_;

	my @who; push @who, [splice @tlist,-5] while @tlist > 5; push @who, [@tlist];

	for ( my $temp = 0; $temp < @who; $temp++ ) {
		my @templist = @{ $who[$temp] };
		my $tempvar = "+v";
		for ( my $temp2 = 0; $temp2 < @templist; $temp2++ ) {
			$tempvar .= "v";
		}
		$irc->yield( mode => $mainchannel => $tempvar => @templist );
	}
	undef;
}

sub devoiceall {
	my (@tlist) = @_;

	my @who; push @who, [splice @tlist,-5] while @tlist > 5; push @who, [@tlist];

	for ( my $temp = 0; $temp < @who; $temp++ ) {
		my @templist = @{ $who[$temp] };
		my $tempvar = "-v";
		for ( my $temp2 = 0; $temp2 < @templist; $temp2++ ) {
			$tempvar .= "v";
		}
		$irc->yield( mode => $mainchannel => $tempvar => @templist );
	}
	undef;
}

sub isplayer {
	my ($nick) = $_[0];
	# Just conducts exists($playerlist{$nick}) and returns the result.

	return exists($playerlist{$nick});
}

sub delete_player {
	my $nick        = shift;
	my $nonspecific = shift;
	if ( isplayer($nick) ) {
		if ( $gamestate >= 2 ) {

			# delete this players vote, if any.
			delete $votelist{$nick};
			# delete all votes for this person, and notify voters.
			while ( my ($key, $value) = each(%votelist) ) {
				if($value eq $nick){
					delete $votelist{$key};
				}
			}

			# Make sure the Seer doesn't scan a dead man.
			my @seerlist = sort(keys(%scan));
			foreach my $seer ( @seerlist ) {
				if ( $scan{$seer} eq $nick ) {
					delete $scan{$seer};
				}
			}

			# Make sure the Angel can't protect a dead man.
			my @angellist = sort(keys(%protect));
			foreach my $angel ( @angellist ) {
				if ( $protect{$angel} eq $nick ) {
					delete $protect{$angel};
				}
			}

			# Make sure the Finder doesn't discover the target of a dead man.
			my @finderlist = sort(keys(%find));
			foreach my $finder ( @finderlist ) {
				if ( $find{$finder} eq $nick ) {
					delete $find{$finder};
				}
			}

			# Make sure the Doppleganger doesn't become a dead man.
			if ( $doppletarget eq $nick ) {
				$doppletarget = '';
			}

			# delete and report, if $nonspecific.
			my $role = $playerlist{$nick}{role};
			$role = "general" if ( $nonspecific and $role ne "Wolf" and $role ne "village_idiot") ;
			my $msg = $texts{$mode}{ "who_died_" . lc $role };
			$msg =~ s/PERSON/\x034{$nick}\x03/g;
			send_notice( $mainchannel, $msg );
			
			# check endgame conditions.
			my $numwolves = 0;
			foreach my $player (values %playerlist){
				$numwolves++ if($player->{role} eq "Wolf");
			}
			if ( $role eq "village_idiot" and $gamestate == 4 and !$nonspecific) {
				#The village idiot has won.
				send_notice( $mainchannel, $texts{$mode}{"end_victory_village_idiot"});
				send_notice( $mainchannel, $texts{$mode}{"end_game"});
				my @rolelist = get_role_list($nick);
				send_notice( $mainchannel, 'Roles: ' . join( ', ', @rolelist ));
				cancelgame();
			} elsif($role eq "Wolf"){
				if($numwolves == 1){
					#The last wolf just died
					send_notice( $mainchannel, $texts{$mode}{"end_victory_villagers"});
					send_notice( $mainchannel, $texts{$mode}{"end_game"});
					my @rolelist = get_role_list($nick);
					send_notice( $mainchannel, 'Roles: ' . join( ', ', @rolelist ));
					cancelgame();
				}
			} else { # this might need more cases if there are more roles!
				if(($numwolves*2) >= ((values %playerlist)-1)){
					#Same number of wolves and others
					send_notice( $mainchannel, $texts{$mode}{"end_victory_wolves"});
					send_notice( $mainchannel, $texts{$mode}{"end_game"});
					my @rolelist = get_role_list($nick);
					send_notice( $mainchannel, 'Roles: ' . join( ', ', @rolelist ));
					cancelgame();
				}
			}
		}
		delete $playerlist{$nick};
		$irc->yield( mode => $mainchannel => '-v' => $nick );
	}
	undef;
}

sub regtime {
	my ($nick) = $_[0];
	# regtime text
	my $msg = $texts{$mode}{who_started};
	$msg =~ s/PERSON/\x034{$nick}\x03/g;
	send_notice($mainchannel,$msg);
	$irc->yield( mode => $mainchannel => '+v' => $nick );
	$playerlist{$nick} = { role => 'villager', };
	$msg = $texts{$mode}{start};
	$msg =~ s/TIME/\x034{$taketime[0]}\x03/g;
	send_notice($mainchannel,$msg);

	$gamestate = 1;
	my $alarmref = $poe_kernel->delay_set( 'reg_end' , $taketime[0] );
	return $alarmref;
}

sub nighttime {
	# nighttime text
	devoiceall( sort(keys(%playerlist)) );
	my $msg = $texts{$mode}{time_night};
	$msg =~ s/TIME/\x034{$taketime[1]}\x03/g;
	send_notice($mainchannel,$msg);
	# Existance check
	my @seerlist = ();
	my @angellist = ();
	my @finderlist = ();
	my $doppleganger = undef;
	my @wolflist = ();
	my @plist = sort(keys(%playerlist));
	for (my $temp = 0; $temp < @plist; $temp++) {
		if ( $playerlist{$plist[$temp]}{role} eq "Seer" ) {
			push @seerlist, $plist[$temp];
		} elsif ( $playerlist{$plist[$temp]}{role} eq "Angel" ) {
			push @angellist, $plist[$temp];
		} elsif ( $playerlist{$plist[$temp]}{role} eq "Finder" ) {
			push @finderlist, $plist[$temp];
		} elsif ( $playerlist{$plist[$temp]}{role} eq "Doppleganger" ) {
			$doppleganger = $plist[$temp];
		} elsif ( $playerlist{$plist[$temp]}{role} eq "Wolf" ) {
			push @wolflist, $plist[$temp];
		}
	}
	$msg = $texts{$mode}{wolf_instruct};
	$msg =~ s/TIME/\x034{$taketime[1]}\x03/g;
	foreach my $target ( @wolflist ) {
		send_notice($target,$msg);
	}
	$msg = $texts{$mode}{seer_instruct};
	$msg =~ s/TIME/\x034{$taketime[1]}\x03/g;
	foreach my $seer ( @seerlist ) {
		send_notice($seer,$msg);
	}
	$msg = $texts{$mode}{angel_instruct};
	$msg =~ s/TIME/\x034{$taketime[1]}\x03/g;
	foreach my $angel ( @angellist ) {
		send_notice($angel,$msg);
	}
	$msg = $texts{$mode}{finder_instruct};
	$msg =~ s/TIME/\x034{$taketime[1]}\x03/g;
	foreach my $finder ( @finderlist ) {
		send_notice($finder,$msg);
	}
	if ( $doppleganger ) {
		$msg = $texts{$mode}{doppleganger_instruct};
		$msg =~ s/TIME/\x034{$taketime[1]}\x03/g;
		send_notice($doppleganger,$msg);
	}

	$gamestate = 2;
	my $alarmref = $poe_kernel->delay_set( 'night_end' , $taketime[1] );
	return $alarmref;
}

sub daytime {
	# daytime text
	voiceall( sort(keys(%playerlist)) );
	my $msg = $texts{$mode}{time_day};
	$msg =~ s/TIME/\x034{$taketime[2]}\x03/g;
	send_notice($mainchannel,$msg);

	$gamestate = 3;
	my $alarmref = $poe_kernel->delay_set( 'vote_start' , $taketime[2] );
	return $alarmref;
}

sub votetime {
	# votetime text
	my $msg = $texts{$mode}{time_vote};
	$msg =~ s/TIME/\x034{$taketime[3]}\x03/g;
	send_notice($mainchannel,$msg);

	$gamestate = 4;
	my $alarmref = $poe_kernel->delay_set( 'day_end' , $taketime[3] );
	return $alarmref;
}

sub cancelgame {
	# Cancels the game. This will get called a lot. Doesn't print text... this routine doesn't care why the game was cancelled.

	$gamestate = 0;
	$poe_kernel->alarm_remove( $nextevent );
	$irc->yield( mode => $mainchannel => '-m' );
	if ( $mode == 3 ) {
		$irc->yield( mode => $mainchannel => '-u' );
	}
	$mode = 0;
	devoiceall( sort(keys(%playerlist)) );
	# Reset variables here.
	%playerlist = ();
	%votelist = ();
	%scan = ();
	%protect = ();
	%find = ();
	$doppletarget = '';
	$mode = 0;
	$gamestate = 0;
	$nextevent = undef;
	undef;
}

sub select_most_votes {
	my $report = shift;
	my @votes = @_;
	my %num;

	# Associate number of votes with a name
	foreach my $vote (@votes) {
		my $key = $vote;
		if(exists($num{$key})){
			$num{$key}++;
		} else{
			$num{$key} = 1;
		}
	}
	if($report){
		my @votemsg = ();
		while ( my ($key, $value) = each(%num) ) {
			push @votemsg, "$key - $value";
		}
		if ( scalar @votemsg ) {
			my $msg = 'Votes: ' . join(', ', @votemsg);
			send_notice($mainchannel, $msg);
		} else {
			send_notice($mainchannel, 'No votes.' );
		}
	}
	# Select names with most votes 
	my @names = ();
	my $num = 0;
	while ( my ($key, $value) = each(%num) ) {
		if ( $value == $num ) {
			push @names, $key;
		} elsif ($value > $num ){
			@names = ( $key );
			$num = $value;
		}
	}

	# Pick most evil person
	if(@names > 1){
		send_notice($mainchannel,'Tie vote, picking at random...') if $report;
		return $names[rand(@names)];
	} else {
		return $names[0];
	}
}

sub guess_nick {
	
	my $guess = shift;
	$guess =~ s/ //g;
	$guess =~ s/,//g;
	$guess =~ s/://g;
	
	# Case-sensitive exact match
	return $guess if(isplayer($guess));
	
	my @one = keys %playerlist;
	my @two = ();
	
	# Start-of-word match
	foreach my $nick (@one){
		push(@two, $nick) if($nick =~ /^$guess/i)
	}
	return @two if(@two <= 1);
	
	# Full word match
	@one = ();
	foreach my $nick (@two){
		push(@one, $nick) if($nick =~ /^$guess$/i)
	}
	return @one if(@one <= 1);
	return @two;
}

sub change_player {
	my $nick = shift;
	my $newname = shift;

	if ( isplayer($nick) ) {

		my $player = delete($playerlist{$nick});
		$playerlist{$newname} = $player;

		if ( exists($votelist{$nick}) ) {
			$player = delete($votelist{$nick});
			$votelist{$newname} = $player;
		}
		while ( my ($key, $value) = each(%votelist) ) {
			if($value eq $nick){
				$votelist{$key} = $newname;
			}
		}
		my @seerlist = sort(keys(%scan));
		foreach my $seer ( @seerlist ) {
			if ( $scan{$seer} eq $nick ) {
				$scan{$seer} = $newname;
			}
		}
		my @angellist = sort(keys(%protect));
		foreach my $angel ( @angellist ) {
			if ( $protect{$angel} eq $nick ) {
				$protect{$angel} = $newname;
			}
		}
		my @finderlist = sort(keys(%find));
		foreach my $finder ( @finderlist ) {
			if ( $find{$finder} eq $nick ) {
				$find{$finder} = $newname;
			}
		}
	}
	
	undef;
}

sub create_roles {
	# Gather roles
	my @roles = ();
	my @players = keys %playerlist;
	if ( $randomroles == 1 ) {
		if ( rand() > 0.5 and $toggleseer ) {
			push @roles, "Seer";
		}
		if ( rand() > 0.5 and $toggleangel ) {
			push @roles, "Angel";
		}
		if ( rand() > 0.5 and $toggleidiot ) {
			push @roles, "village_idiot";
		}
		if ( rand() > 0.5 and scalar(@players)*.75 > scalar(@roles) and $toggledoppleganger ) {
			push @roles, "Doppleganger";
		}
		if ( rand() > 0.5 and scalar(@players)*.75 > scalar(@roles) and $togglefinder ) {
			push @roles, "Finder";
		}
	} else {
		if ( $toggleseer ) {
			push @roles, "Seer";
		}
		if ( $toggleangel ) {
			push @roles, "Angel";
		}
		if ( $toggleidiot ) {
			push @roles, "village_idiot";
		}
		if ( scalar(@players)*.75 > scalar(@roles) and $toggledoppleganger ) {
			push @roles, "Doppleganger";
		}
		if ( scalar(@players)*.75 > scalar(@roles) and $togglefinder ) {
			push @roles, "Finder";
		}
	}
	for(1..(scalar @players)/4){
		push @roles, "Wolf";
	}
	#(Add other roles here)  
	
	my @wolves;
	# Hand out roles
	foreach my $role (@roles){
		my $player = splice(@players,rand(scalar @players),1);
		send_notice($player,$texts{$mode}{'is_' . lc $role});
		$playerlist{$player}{role} = $role;
		push @wolves,$player if ($role eq "Wolf");
	}
	# Inform the wolves of the other wolves, if necessary
	if(@wolves > 1){
		my $msg = $texts{$mode}{'is_wolf_list'};
		my $wolflist = join(', ',@wolves);
		$msg =~ s/WOLFLIST/\x034{$wolflist}\x03/g;
		foreach my $player (@wolves){
			send_notice($player,$msg);
		}
	}
	send_notice($mainchannel,$texts{$mode}{'is_villager_inform'});
}

sub get_role_list {
	my $exclude = shift;

	my @rolelist = ();
	while ( my ($key, $value) = each(%playerlist) ) {
		if ($key ne $exclude) {
			my $tempval = $value->{role};
			$tempval =~ s/Wolf/$texts{$mode}{role_name_wolf}/g;
			$tempval =~ s/Seer/$texts{$mode}{role_name_seer}/g;
			$tempval =~ s/Angel/$texts{$mode}{role_name_angel}/g;
			$tempval =~ s/village_idiot/$texts{$mode}{role_name_village_idiot}/g;
			$tempval =~ s/Doppleganger/$texts{$mode}{role_name_doppleganger}/g;
			$tempval =~ s/Finder/$texts{$mode}{role_name_finder}/g;
			$tempval =~ s/villager/$texts{$mode}{role_name_villager}/g;
			push @rolelist, "$key - $tempval";
		}
	}
	return @rolelist;
}

sub skiptime {
	if ( $gamestate > 0 ) {
		$poe_kernel->alarm_remove( $nextevent );
		if ( $gamestate == 1 ) {
			reg_end();
		} elsif ( $gamestate == 2 ) {
			night_end();
		} elsif ( $gamestate == 3 ) {
			vote_start();
		} elsif ( $gamestate == 4 ) {
			day_end();
		}
	}

	undef;
}

sub stoptime {
	if ( $gamestate > 0 ) {
		$poe_kernel->alarm_remove( $nextevent );
	}

	undef;
}
