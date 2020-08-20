namespace Xmpp.Xep.MessageFastening {

    private const string NS_URI = "urn:xmpp:fasten:0";

    public static void set_replace_id(MessageStanza message, string replace_id, bool remove_fastening = false) {
        StanzaNode fastening_node = (new StanzaNode.build("apply-to", NS_URI)).add_self_xmlns().put_attribute("id", replace_id);
        
        if (remove_fastening) fastening_node.put_attribute("clear", remove_fastening.to_string());
        
        message.stanza.put_node(fastening_node);
    }

    public static string? get_replace_id(MessageStanza message) {
        StanzaNode? node = message.stanza.get_subnode("apply-to", NS_URI);
        if (node == null) return null;
    
        return node.get_attribute("id");
    }

    public class Module : XmppStreamModule {
        public static ModuleIdentity<Module> IDENTITY = new ModuleIdentity<Module>(NS_URI, "0422_message_fastening");
    
        public override void attach(XmppStream stream) {
            stream.get_module(ServiceDiscovery.Module.IDENTITY).add_feature(stream, NS_URI);
        }
    
        public override void detach(XmppStream stream) {
            stream.get_module(ServiceDiscovery.Module.IDENTITY).remove_feature(stream, NS_URI);
        }
    
        public override string get_ns() { return NS_URI; }
    
        public override string get_id() { return IDENTITY.id; }
    }
    
    }