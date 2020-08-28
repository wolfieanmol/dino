using Gee;

namespace Xmpp {

    public class RttStanzaNode : Object {
    
        public const string ATTRIBUTE_SEQUENCE = "seq";
        public const string ATTRIBUTE_ID = "id";
        public const string ATTRIBUTE_EVENT = "event";
    
        public string seq {
            get {
                return stanza_node.get_attribute(ATTRIBUTE_SEQUENCE);
            }
            set { stanza_node.set_attribute(ATTRIBUTE_SEQUENCE, value); }
        }

        public virtual string? id {
            get { return stanza_node.get_attribute(ATTRIBUTE_ID); }
            set { if (value != null) stanza_node.set_attribute(ATTRIBUTE_ID, value); }
        }
    
        public virtual string event {
            get {
                return stanza_node.get_attribute(ATTRIBUTE_EVENT);
            }
            set { stanza_node.set_attribute(ATTRIBUTE_EVENT, value); }
        }
    
        public StanzaNode stanza_node;
    
        public RttStanzaNode(ArrayList<StanzaNode>? sub_nodes) {
            if (sub_nodes != null) {
                this.stanza_node = new StanzaNode.build("rtt", Xep.RealTimeText.NS_URI, sub_nodes).add_self_xmlns();
            } else {
                this.stanza_node = new StanzaNode.build("rtt", Xep.RealTimeText.NS_URI).add_self_xmlns();
            }
        }
        
    }
    
    }