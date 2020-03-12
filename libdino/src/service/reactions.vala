using Gee;
using Qlite;

using Xmpp;
using Xmpp.Xep;
using Dino.Entities;

namespace Dino {
public class Reactions : StreamInteractionModule, Object {
    public static ModuleIdentity<Reactions> IDENTITY = new ModuleIdentity<Reactions>("reactions");
    public string id { get { return IDENTITY.id; } }

    public signal void reaction_added(Account account, int content_item_id, Jid jid, string reaction);
//    [Signal(detailed=true)]
    public signal void reaction_removed(Account account, int content_item_id, Jid jid, string reaction);

    private StreamInteractor stream_interactor;
    private Database db;

    public static void start(StreamInteractor stream_interactor, Database database) {
        Reactions m = new Reactions(stream_interactor, database);
        stream_interactor.add_module(m);
    }

    private Reactions(StreamInteractor stream_interactor, Database database) {
        this.stream_interactor = stream_interactor;
        this.db = database;
        stream_interactor.account_added.connect(on_account_added);
    }

    public void add_reaction(Conversation conversation, ContentItem content_item, string reaction) {
        Gee.List<string> reactions = get_own_reactions(conversation, content_item);
        if (!reactions.contains(reaction)) {
            reactions.add(reaction);
        }
        send_reactions(conversation.account, content_item, reactions);
        reaction_added(conversation.account, content_item.id, conversation.account.bare_jid, reaction);
    }

    public void remove_reaction(Conversation conversation, ContentItem content_item, string reaction) {
        Gee.List<string> reactions = get_own_reactions(conversation, content_item);
        reactions.remove(reaction);
        send_reactions(conversation.account, content_item, reactions);
        reaction_removed(conversation.account, content_item.id, conversation.account.bare_jid, reaction);
    }

    public HashMap<string, Gee.List<Jid>> get_item_reactions(Conversation conversation, ContentItem content_item) {
        if (conversation.type_ == Conversation.Type.CHAT) {
            return get_chat_message_reactions(conversation.account, content_item);
        } else {
            return get_muc_message_reactions(conversation.account, content_item);
        }
    }

    public bool conversation_supports_reactions(Conversation conversation) {
        if (conversation.type_ == Conversation.Type.CHAT) {
            Gee.List<Jid>? resources = stream_interactor.get_module(PresenceManager.IDENTITY).get_full_jids(conversation.counterpart, conversation.account);
            if (resources == null) return false;

            foreach (Jid full_jid in resources) {
                XmppStream? stream = stream_interactor.get_stream(conversation.account);
                if (stream == null) return false;
                bool? has_feature = stream.get_flag(ServiceDiscovery.Flag.IDENTITY).has_entity_feature(full_jid, Xep.Reactions.NS_URI);
                if (has_feature == true) {
                    return true;
                }
            }
        } else {
            XmppStream? stream = stream_interactor.get_stream(conversation.account);
            if (stream == null) return false;
            bool? has_feature = stream.get_flag(ServiceDiscovery.Flag.IDENTITY).has_entity_feature(conversation.counterpart, OccupantIds.NS_URI);
            return has_feature == true;
        }
        return false;
    }

    private void send_reactions(Account account, ContentItem content_item, Gee.List<string> reactions) {
        Message? message = null;

        FileItem? file_item = content_item as FileItem;
        if (file_item != null) {
            int message_id = int.parse(file_item.file_transfer.info);
            message = stream_interactor.get_module(MessageStorage.IDENTITY).get_message_by_id(message_id);
        }
        MessageItem? message_item = content_item as MessageItem;
        if (message_item != null) {
            message = message_item.message;
        }

        if (message == null) {
            return;
        }

        Conversation? conversation = stream_interactor.get_module(ConversationManager.IDENTITY).get_conversation_for_message(message); // TODO use conversation
        XmppStream stream = stream_interactor.get_stream(account);
        if (conversation.type_ == Conversation.Type.GROUPCHAT || conversation.type_ == Conversation.Type.GROUPCHAT_PM) {
            if (conversation.type_ == Conversation.Type.GROUPCHAT) {
                stream.get_module(Xmpp.Xep.Reactions.Module.IDENTITY).send_reaction(stream, conversation.counterpart, "groupchat", message.server_id ?? message.stanza_id, reactions);
            } else if (conversation.type_ == Conversation.Type.GROUPCHAT_PM) {
                stream.get_module(Xmpp.Xep.Reactions.Module.IDENTITY).send_reaction(stream, conversation.counterpart, "chat", message.server_id ?? message.stanza_id, reactions);
            }
        } else if (conversation.type_ == Conversation.Type.CHAT) {
            stream.get_module(Xmpp.Xep.Reactions.Module.IDENTITY).send_reaction(stream, conversation.counterpart, "chat", message.stanza_id, reactions);
            var datetime_now = new DateTime.now();
            long now_long = (long) (datetime_now.to_unix() * 1000 + datetime_now.get_microsecond());
            save_chat_reaction(account, account.bare_jid, content_item.id, now_long, reactions);
        }
    }

    private Gee.List<string> get_own_reactions(Conversation conversation, ContentItem content_item) {
        if (conversation.type_ == Conversation.Type.CHAT) {
            return get_chat_user_reactions(conversation.account, content_item.id, conversation.account.bare_jid);
        } else if (conversation.type_ == Conversation.Type.GROUPCHAT) {
            string own_occupant_id = stream_interactor.get_module(MucManager.IDENTITY).get_own_occupant_id(conversation.account, content_item.jid);
            return get_muc_user_reactions(conversation.account, content_item.id, own_occupant_id);
        }
        return new ArrayList<string>();
    }

    private struct ReactionsTime {
        public string emojis;
        public long time;
    }

    private Gee.List<string> get_chat_user_reactions(Account account, int content_item_id, Jid jid) {
        int jid_id = db.get_jid_id(jid);

        QueryBuilder query = db.reaction.select()
            .with(db.reaction.account_id, "=", account.id)
            .with(db.reaction.content_item_id, "=", content_item_id)
            .with(db.reaction.jid_id, "=", jid_id);

        RowOption row = query.single().row();
        if (row.is_present()) {
            return string_to_emoji_list(row[db.reaction.emojis]);
        }
        return new ArrayList<string>();
    }

    private Gee.List<string> get_muc_user_reactions(Account account, int content_item_id, string occupantid) {
        QueryBuilder query = db.reaction.select()
                .with(db.reaction.account_id, "=", account.id)
                .with(db.reaction.content_item_id, "=", content_item_id)
                .join_with(db.occupantid, db.occupantid.id, db.reaction.occupant_id)
                .with(db.occupantid.occupant_id, "=", occupantid);

        RowOption row = query.single().row();
        if (row.is_present()) {
            return string_to_emoji_list(row[db.reaction.emojis]);
        }
        return new ArrayList<string>();
    }

    private ReactionsTime? get_user_reactions_time(Account account, int content_item_id, Jid jid) {
        RowOption row = db.reaction.select()
                .with(db.reaction.account_id, "=", account.id)
                .with(db.reaction.content_item_id, "=", content_item_id)
                .with(db.reaction.jid_id, "=", db.get_jid_id(jid))
                .single().row();

        ReactionsTime? ret = null;
        if (row.is_present()) {
            var tuple = ReactionsTime();
            tuple.emojis = row[db.reaction.emojis];
            tuple.time = row[db.reaction.time];
        }
        return ret;
    }

    private Gee.List<string> string_to_emoji_list(string emoji_str) {
        ArrayList<string> ret = new ArrayList<string>();
        foreach (string emoji in emoji_str.split(",")) {
            if (emoji.length != 0)
            ret.add(emoji);
        }
        return ret;
    }

    public HashMap<string, Gee.List<Jid>> get_chat_message_reactions(Account account, ContentItem content_item) {
        QueryBuilder select = db.reaction.select()
                .with(db.reaction.account_id, "=", account.id)
                .with(db.reaction.content_item_id, "=", content_item.id);

        HashMap<string, Gee.List<Jid>> ret = new HashMap<string, Gee.List<Jid>>();
        foreach (Row row in select) {
            string emoji_str = row[db.reaction.emojis];
            Jid jid = db.get_jid_by_id(row[db.reaction.jid_id]);

            foreach (string emoji in emoji_str.split(",")) {
                if (!ret.contains(emoji)) {
                    ret[emoji] = new ArrayList<Jid>(Jid.equals_func);
                }
                ret.get(emoji).add(jid);
            }
        }
        return ret;
    }

    public HashMap<string, Gee.List<Jid>> get_muc_message_reactions(Account account, ContentItem content_item) {
        QueryBuilder select = db.reaction.select()
                .with(db.reaction.account_id, "=", account.id)
                .with(db.reaction.content_item_id, "=", content_item.id)
                .join_with(db.occupantid, db.occupantid.id, db.reaction.occupant_id);

        string? own_occupant_id = stream_interactor.get_module(MucManager.IDENTITY).get_own_occupant_id(account, content_item.jid);

        HashMap<string, Gee.List<Jid>> ret = new HashMap<string, Gee.List<Jid>>();
        foreach (Row row in select) {
            string emoji_str = row[db.reaction.emojis];

            Jid jid = null;
            if (row[db.occupantid.occupant_id] == own_occupant_id) {
                jid = account.bare_jid;
            } else {
                string nick = row[db.occupantid.last_nick];
                jid = content_item.jid.with_resource(nick);
            }

            foreach (string emoji in emoji_str.split(",")) {
                if (!ret.contains(emoji)) {
                    ret[emoji] = new ArrayList<Jid>(Jid.equals_func);
                }
                ret.get(emoji).add(jid);
            }
        }
        return ret;
    }

    private void on_account_added(Account account) {
        // TODO get time from delays
        stream_interactor.module_manager.get_module(account, Xmpp.Xep.Reactions.Module.IDENTITY).received_reactions.connect((stream, jid, message_id, reactions, stanza) => {
            on_reaction_received(account, stream, jid, message_id, reactions, stanza);
        });
    }

    private void on_reaction_received(Account account, XmppStream stream, Jid jid, string message_id, Gee.List<string> reactions, MessageStanza stanza) {
        if (stanza.type_ == MessageStanza.TYPE_GROUPCHAT) {
            // We only accept reactions in MUCs if they support occupant ids
            bool? has_feature = stream.get_flag(ServiceDiscovery.Flag.IDENTITY).has_entity_feature(jid.bare_jid, OccupantIds.NS_URI);
            if (has_feature == null || has_feature == false) return;
        }

        var select = db.message.select()
            .with(db.message.account_id, "=", account.id);
        if (stanza.type_ == MessageStanza.TYPE_CHAT) {
            if (!jid.equals_bare(account.bare_jid)) {
                select.with(db.message.counterpart_id, "=", db.get_jid_id(jid))
                    .with(db.message.stanza_id, "=", message_id);
            }
        } else {
            select.with(db.message.server_id, "=", message_id);
        }

        RowOption row = select.single().row();
        if (!row.is_present()) {
            print("got reaction but dont have message\n");
            return;
        }

        RowOption file_transfer_row = db.file_transfer.select()
                .with(db.file_transfer.account_id, "=", account.id)
                .with(db.file_transfer.info, "=", row[db.message.id].to_string())
                .single().row(); // TODO better

        var content_item_row = db.content_item.select();

        if (file_transfer_row.is_present()) {
            content_item_row.with(db.content_item.foreign_id, "=", file_transfer_row[db.file_transfer.id])
                    .with(db.content_item.content_type, "=", 2);
        } else {
            content_item_row.with(db.content_item.foreign_id, "=", row[db.message.id])
                    .with(db.content_item.content_type, "=", 1);
        }
        var content_item_row_opt = content_item_row.single().row();
        if (!content_item_row_opt.is_present()) return;
        int content_item_id = content_item_row_opt[db.content_item.id];

        // Get reaction time
        DateTime? reaction_time = null;
        DelayedDelivery.MessageFlag? delayed_message_flag = DelayedDelivery.MessageFlag.get_flag(stanza);
        if (delayed_message_flag != null) reaction_time = delayed_message_flag.datetime;
        if (reaction_time == null) {
            MessageArchiveManagement.MessageFlag? mam_message_flag = MessageArchiveManagement.MessageFlag.get_flag(stanza);
            if (mam_message_flag != null) reaction_time = mam_message_flag.server_time;
            if (reaction_time == null) reaction_time = new DateTime.now_local();
        }
        long reaction_time_long = (long) (reaction_time.to_unix() * 1000 + reaction_time.get_microsecond());

        ReactionsTime? reactions_time = get_user_reactions_time(account, content_item_id, jid);
        if (reactions_time != null) {
            if (reaction_time_long < reactions_time.time) {
                // We already have a more recent reaction already
                return;
            }
        }

        // Get current reactions
        string? occupant_id = OccupantIds.get_occupant_id(stream, stanza.stanza);
        Gee.List<string>? current_reactions = null;
        if (stanza.type_ == MessageStanza.TYPE_GROUPCHAT) {
            current_reactions = get_muc_user_reactions(account, content_item_id, occupant_id);
        } else if (stanza.type_ == MessageStanza.TYPE_CHAT) {
            current_reactions = get_chat_user_reactions(account, content_item_id, jid);
        }

        // Notify about reaction changes
        var matching_reactions = new ArrayList<string>();
        for (int i = 0; i < current_reactions.size; i++) {
            if (reactions.contains(current_reactions[i])) {
                matching_reactions.add(current_reactions[i]);
            }
        }
        Jid signal_jid = jid;
        if (stanza.type_ == MessageStanza.TYPE_GROUPCHAT &&
                signal_jid.equals(stream_interactor.get_module(MucManager.IDENTITY).get_own_jid(jid, account))) {
            signal_jid = account.bare_jid;
        }
        foreach (string current_reaction in current_reactions) {
            if (!matching_reactions.contains(current_reaction)) {
                reaction_removed(account, content_item_id, signal_jid, current_reaction);
            }
        }
        foreach (string reaction in reactions) {
            if (!matching_reactions.contains(reaction)) {
                reaction_added(account, content_item_id, signal_jid, reaction);
            }
        }

        // Save reactions

        if (stanza.type_ == MessageStanza.TYPE_CHAT) {
            save_chat_reaction(account, jid, content_item_id, reaction_time_long, reactions);
        } else if (stanza.type_ == MessageStanza.TYPE_GROUPCHAT) {
            save_muc_reaction(account, occupant_id, jid, content_item_id, reaction_time_long, reactions);
        }
    }

    private void save_chat_reaction(Account account, Jid jid, int content_item_id, long reaction_time, Gee.List<string> reactions) {
        var emoji_builder = new StringBuilder();
        for (int i = 0; i < reactions.size; i++) {
            if (i != 0) emoji_builder.append(",");
            emoji_builder.append(reactions[i]);
        }

        db.reaction.upsert()
                .value(db.reaction.account_id, account.id, true)
                .value(db.reaction.content_item_id, content_item_id, true)
                .value(db.reaction.jid_id, db.get_jid_id(jid), true)
                .value(db.reaction.emojis, emoji_builder.str, false)
                .value(db.reaction.time, reaction_time, false)
                .perform();
    }

    private void save_muc_reaction(Account account, string occupant_id, Jid jid, int content_item_id, long reaction_time, Gee.List<string> reactions) {
        int jid_id = db.get_jid_id(jid);

        var emoji_builder = new StringBuilder();
        for (int i = 0; i < reactions.size; i++) {
            if (i != 0) emoji_builder.append(",");
            emoji_builder.append(reactions[i]);
        }

        RowOption row = db.occupantid.select()
                .with(db.occupantid.account_id, "=", account.id)
                .with(db.occupantid.jid_id, "=", jid_id)
                .with(db.occupantid.occupant_id, "=", occupant_id)
                .single().row();

        int occupant_db_id = -1;
        if (row.is_present()) {
            occupant_db_id = row[db.occupantid.id];
        } else {
            occupant_db_id = (int)db.occupantid.upsert()
                .value(db.occupantid.account_id, account.id, true)
                .value(db.occupantid.jid_id, jid_id, true)
                .value(db.occupantid.occupant_id, occupant_id, true)
                .value(db.occupantid.last_nick, jid.resourcepart, false)
                .perform();
        }

        db.reaction.upsert()
                .value(db.reaction.account_id, account.id, true)
                .value(db.reaction.content_item_id, content_item_id, true)
                .value(db.reaction.occupant_id, (int)occupant_db_id, true)
                .value(db.reaction.emojis, emoji_builder.str, false)
                .value(db.reaction.time, reaction_time, false)
                .perform();
    }
}

}
