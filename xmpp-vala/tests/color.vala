using Xmpp.Xep;

namespace Xmpp.Test {

class ColorTest : Gee.TestCase {

    public ColorTest() {
        base("color");

        add_test("xep-vectors", () => { test_xep_vectors(); });
        add_test("rgb-to-angle", () => { test_rgb_to_angle(); });
    }

    private void test_consistent_color_float(string s, float r, float g, float b, ConsistentColor.VisionDeficiency def = ConsistentColor.VisionDeficiency.NONE) {
        ConsistentColor.RGB rgb = ConsistentColor.string_to_rgb(s, def);
        fail_if_not_eq_float(rgb.r/255f, r, 1);
        fail_if_not_eq_float(rgb.g/255f, g, 1);
        fail_if_not_eq_float(rgb.b/255f, b, 1);
    }

    public void test_xep_vectors() {
        uint8[] rgb;

        test_consistent_color_float("Romeo", 0.281f, 0.790f, 1f);
        test_consistent_color_float("juliet@capulet.lit", 0.337f, 1f, 0f);
        test_consistent_color_float("😺", 0.347f, 0.756f, 1f);
        test_consistent_color_float("council", 0.732f, 0.56f, 1f);

        test_consistent_color_float("Romeo", 1f, 0.674f, 0f, ConsistentColor.VisionDeficiency.REDGREEN);
        test_consistent_color_float("juliet@capulet.lit", 1f, 0.359f, 1f, ConsistentColor.VisionDeficiency.REDGREEN);
        test_consistent_color_float("😺", 1f, 0.708f, 0f, ConsistentColor.VisionDeficiency.REDGREEN);
        test_consistent_color_float("council", 0.732f, 0.904f, 0f, ConsistentColor.VisionDeficiency.REDGREEN);

        test_consistent_color_float("Romeo", 1f, 0.674f, 0f, ConsistentColor.VisionDeficiency.BLUE);
        test_consistent_color_float("juliet@capulet.lit", 0.337f, 1f, 0f, ConsistentColor.VisionDeficiency.BLUE);
        test_consistent_color_float("😺", 1f, 0.708f, 0f, ConsistentColor.VisionDeficiency.BLUE);
        test_consistent_color_float("council", 0.732f, 0.904f, 0f, ConsistentColor.VisionDeficiency.BLUE);
    }

    public void test_rgb_to_angle() {
        string[] colors = {"e57373", "f06292", "ba68c8", "9575cd", "7986cb", "64b5f6", "4fc3f7", "4dd0e1", "4db6ac", "81c784", "aed581", "dce775", "fff176", "ffd54f", "ffb74d", "ff8a65"};
        foreach(string hex_color in colors) {
            uint8 r = (uint8) ((double) hex_color.substring(0, 2).to_long(null, 16));
            uint8 g = (uint8) ((double) hex_color.substring(2, 2).to_long(null, 16));
            uint8 b = (uint8) ((double) hex_color.substring(4, 2).to_long(null, 16));
            //print(@"$hex_color, $r, $g, $b, $(ConsistentColor.rgb_to_angle(r, g, b))\n");
        }
    }
}

}