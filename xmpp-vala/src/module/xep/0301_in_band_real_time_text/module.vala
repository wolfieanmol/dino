using Gee;

using Xmpp;
using Xmpp.Xep;

namespace Xmpp.Xep.RealTimeText {

    public const string NS_URI = "urn:xmpp:rtt:0";
   
    public enum Event {
        NEW,
        RESET,
        EDIT,
        INIT,
        CANCEL
    }

    public enum ActionElement {
        INSERT_TEXT,
        ERASE_TEXT,
        WAIT
    }

    public enum ActionElementAttribute {
        POSITION,
        LENGTH,
        WAIT_INTERVAL
    }

    public class Module : XmppStreamModule {
        public static ModuleIdentity<Module> IDENTITY = new ModuleIdentity<Module>(NS_URI, "0301_in_band_real_time_text");

        public const string  EVENT_NEW  = "new";
        public const string  EVENT_RESET  = "reset";
        public const string  EVENT_EDIT = "edit";
        public const string  EVENT_INIT = "init";
        public const string  EVENT_CANCEL  = "cancel";

        public const string ACTION_ELEMENT_INSERT = "t";
        public const string ACTION_ELEMENT_ERASE = "e";
        public const string ACTION_ELEMENT_WAIT = "w";

        public const string ATTRIBUTE_POSITION = "p";
        public const string ATTRIBUTE_LENGTH = "n";
        public const string ATTRIBUTE_WAIT_INTERVAL = "n";

        public HashMap<Jid, bool> ignore = new HashMap<Jid, bool>(Jid.hash_func, Jid.equals_func);
        public HashMap<Jid, int> previous_sequence = new HashMap<Jid, int>(Jid.hash_func, Jid.equals_func);

        public signal void rtt_sent(Jid jid, MessageStanza message);
        public signal void rtt_received(Jid jid, MessageStanza stanza, Gee.List<StanzaNode> action_elements, Jid? to_jid = null);
        public signal void reset_rtt_received(Jid jid, MessageStanza stanza, StanzaNode text, Jid? to_jid = null);
        public signal void event_received(Jid jid, MessageStanza stanza, string event, Jid? to_jid = null);

        public override void attach(XmppStream stream) {
            stream.get_module(MessageModule.IDENTITY).received_message.connect(on_received_message);
            stream.get_module(ServiceDiscovery.Module.IDENTITY).add_feature(stream, NS_URI);
        }
    
        public override void detach(XmppStream stream) {
            stream.get_module(MessageModule.IDENTITY).received_message.disconnect(on_received_message);
            stream.get_module(ServiceDiscovery.Module.IDENTITY).remove_feature(stream, NS_URI);
        }
    
        public override string get_ns() { return NS_URI; }
    
        public override string get_id() { return IDENTITY.id; }

        public StanzaNode generate_t_element(XmppStream stream, string text, string? position = null) {
           StanzaNode insert_text = new StanzaNode.build(ACTION_ELEMENT_INSERT, NS_URI);
           if (position != null) {
               insert_text.put_attribute(ATTRIBUTE_POSITION, position, NS_URI);
           }
           insert_text.put_node(new StanzaNode.text(text));

           return insert_text;
        }

        public StanzaNode generate_e_element(XmppStream stream, string? position, string? length) {
            StanzaNode erase_text = new StanzaNode.build(ACTION_ELEMENT_ERASE, NS_URI);
            if (position != null) {
                erase_text.put_attribute(ATTRIBUTE_POSITION, position, NS_URI);
            }
            if (length != null) {
                erase_text.put_attribute(ATTRIBUTE_LENGTH, length, NS_URI);
            }

            return erase_text;
        }

        public StanzaNode generate_w_element(XmppStream stream, string? wait_interval) {
            StanzaNode wait_action_element = new StanzaNode.build(ACTION_ELEMENT_WAIT, NS_URI);
            wait_action_element.put_attribute(ATTRIBUTE_WAIT_INTERVAL, wait_interval, NS_URI);

            return wait_action_element;
        }

        public void send_rtt(XmppStream stream, Jid jid, string message_type, string sequence, string? event, ArrayList<StanzaNode>? action_elements = null) {
            MessageStanza message = new MessageStanza() { to=jid, type_=message_type };
            RttStanzaNode rtt_node = new RttStanzaNode(action_elements) { seq=sequence, event=event };
           
            message.stanza.put_node(rtt_node.stanza_node);
            MessageProcessingHints.set_message_hint(message, MessageProcessingHints.HINT_NO_STORE);
            
            stream.get_module(MessageModule.IDENTITY).send_message.begin(stream, message);
            rtt_sent(jid, message);
        }

        private void on_received_message(XmppStream stream, MessageStanza message) {
            Jid? from_jid = message.from;
            Jid? to_jid = MessageCarbons.MessageFlag.get_flag(message) != null ? message.to : null;
            StanzaNode? rtt_stanza_node = message.stanza.get_subnode("rtt", NS_URI);
            
            if (rtt_stanza_node != null) {
                // event resolution
                string? event = rtt_stanza_node.get_attribute("event", NS_URI);
                if (event == null) event = EVENT_EDIT;

                if (event == EVENT_RESET || event == EVENT_NEW) ignore[from_jid] = false;
                
                //  handle_event(string event);
                event_received(from_jid, message, event, to_jid);

                if (!ignore[from_jid]) {
                    // sequence resolution
                    int received_sequence = int.parse(rtt_stanza_node.get_attribute("seq", NS_URI));
                    bool is_sequence = true;
                    if (event==EVENT_EDIT &&  received_sequence != previous_sequence[from_jid]+1) is_sequence = false;
                    previous_sequence[from_jid] = received_sequence;
                
                    //get action element subnodes
                    if (is_sequence) { 
                        if (event==EVENT_NEW || event==EVENT_EDIT) {
                            rtt_received(from_jid, message, rtt_stanza_node.get_all_subnodes(), to_jid);
                        } else if (event == EVENT_RESET) {
                            reset_rtt_received(from_jid, message, rtt_stanza_node.get_subnode("t", NS_URI), to_jid);
                        } 
                    } else {
                        ignore[from_jid] = true;
                        //TODO(WOlffie) handle memeory leaks in ignore and seq hash maps.
                    }
                }
            }
        }
    } 
}