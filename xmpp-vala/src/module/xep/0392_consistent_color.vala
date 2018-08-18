namespace Xmpp.Xep.ConsistentColor {
    private const double KR = 0.299;
    private const double KG = 0.587;
    private const double KB = 0.114;
    private const double Y = 0.732;

    public double string_to_angle(string s) {
        Checksum checksum = new Checksum(ChecksumType.SHA1);
        checksum.update(s.data, -1);
        size_t len = 20;
        uint8[] digest = new uint8[len];
        checksum.get_digest(digest, ref len);
        uint16 output = (*(uint16*)digest).to_little_endian();
        double angle = ((double) output) / 65536.0 * 2.0 * Math.PI;
        return angle;
    }

    public double color_vision_correction(double angle, VisionDeficiency def = VisionDeficiency.NONE) {
        switch (def) {
            default:
            case VisionDeficiency.NONE:
                return angle;
            case VisionDeficiency.REDGREEN:
                return angle % (double) Math.PI;
            case VisionDeficiency.BLUE:
                return (angle - Math.PI / 2.0) % Math.PI + Math.PI / 2.0;
        }
    }

    public YCbCr angle_to_ycbcr(double angle) {
        double cr = (double) Math.sin(angle);
        double cb = (double) Math.cos(angle);
        double factor = cr.abs() > cb.abs() ? (0.5 / cr.abs()) : (0.5 / cb.abs());
        cb *= factor;
        cr *= factor;
        return new YCbCr(Y, cb, cr);
    }

    public RGBf ycbcr_to_rgbf(YCbCr ycbcr) {
        double cb = ycbcr.cb, cr = ycbcr.cr, y = ycbcr.y;
        double r = 2.0 * (1.0 - KR) * cr + y;
        double b = 2.0 * (1.0 - KB) * cb + y;
        double g = (Y - KR * r - KB * b) / KG;
        return new RGBf(r, g, b);
    }

    public RGB ycbcr_to_rgb(YCbCr ycbcr) {
        return RGB.from_rgbf(ycbcr_to_rgbf(ycbcr));
    }

    public YCbCr rgb_to_ycbcr(RGB rgb) {
        RGBf rgb_ = RGBf.from_rgb(rgb);
        double y = KR * rgb_.r + (1 - KR - KB) * rgb_.g + KB * rgb_.b;
        double cb = (rgb_.b - y) / (1 - KB) / 2;
        double cr = (rgb_.r - y) / (1 - KR) / 2;
        return new YCbCr(Y, cb, cr);
    }

    public double ycbcr_to_angle(YCbCr cbcr) {
        double cb = cbcr.cb, cr = cbcr.cr;
        double magn = (double) Math.sqrt(Math.pow(cb, 2) + Math.pow(cr, 2));
        if (magn > 0) {
            cr /= magn;
            cb /= magn;
        }
        double angle = (double) (Math.atan2(cr, cb) % (2.0 * Math.PI));
        return angle;
    }

    public double rgb_to_angle(RGB rgb) {
        YCbCr ycbcr = rgb_to_ycbcr(rgb);
        return ycbcr_to_angle(ycbcr);
    }

    public RGB string_to_rgb(string s, VisionDeficiency def = VisionDeficiency.NONE) {
        double angle = string_to_angle(s);
        angle = color_vision_correction(angle, def);
        YCbCr ycbcr = angle_to_ycbcr(angle);
        RGB rgb =  ycbcr_to_rgb(ycbcr);
        return rgb;
    }

    public RGB rgb_for_background(RGB fg, RGB bg) {
        return new RGB(
                (uint8) (0.2 * (255 - bg.r) + 0.8 * fg.r),
                (uint8) (0.2 * (255 - bg.g) + 0.8 * fg.g),
                (uint8) (0.2 * (255 - bg.b) + 0.8 * fg.b)
            );
    }

    public struct RGB {
        uint8 r;
        uint8 g;
        uint8 b;

        public RGB(uint8 r, uint8 g, uint8 b) {
            this.r = r;
            this.g = g;
            this.b = b;
        }

        public static RGB from_rgbf(RGBf rgb) {
            return RGB(
                    (uint8) Math.round(255.0 * double.max(double.min(rgb.r, 1), 0)),
                    (uint8) Math.round(255.0 * double.max(double.min(rgb.g, 1), 0)),
                    (uint8) Math.round(255.0 * double.max(double.min(rgb.b, 1), 0))
                );
        }
    }

    public struct RGBf {
        double r;
        double g;
        double b;

        public RGBf(double r, double g, double b) {
            this.r = r;
            this.g = g;
            this.b = b;
        }

        public static RGBf from_rgb(RGB rgb) {
            return RGBf(rgb.r/255.0, rgb.g/255.0, rgb.b/255.0);
        }
    }

    public struct YCbCr {
        double y;
        double cb;
        double cr;

        public YCbCr(double y, double cb, double cr) {
            this.y = y;
            this.cb = cb;
            this.cr = cr;
        }
    }

    public enum VisionDeficiency {
        NONE,
        REDGREEN,
        BLUE
    }
}