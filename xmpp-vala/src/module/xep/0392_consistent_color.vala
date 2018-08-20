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
        //YCbCr ycbcr = angle_to_ycbcr(angle);
        //RGB rgb =  ycbcr_to_rgb(ycbcr);
        double[] rgb = Hsluv.HpluvToRgb(new double[] {angle * 360.0 / (2.0 * Math.PI), 100, 75});
        return RGB.from_rgbf(new RGBf(rgb[0], rgb[1], rgb[2]));
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

    class Hsluv {
        private static Gee.List<Gee.List<double?>> M_;

        private static Gee.List<Gee.List<double?>> M {
            get {
                if (M_ == null) {
                    M_ = new Gee.ArrayList<Gee.List<double?>>.wrap(new Gee.List<double?>[] {
                        new Gee.ArrayList<double?>.wrap(new double?[] {  3.240969941904521, -1.537383177570093, -0.498610760293    }),
                        new Gee.ArrayList<double?>.wrap(new double?[] { -0.96924363628087,   1.87596750150772,   0.041555057407175 }),
                        new Gee.ArrayList<double?>.wrap(new double?[] {  0.055630079696993, -0.20397695888897,   1.056971514242878 }),
                    });
                }
                return M_;
            }
        }

        private static Gee.List<Gee.List<double?>> MInv_;

        private static Gee.List<Gee.List<double?>> MInv {
            get {
                if (MInv_ == null) {
                    MInv_ = new Gee.ArrayList<Gee.List<double?>>.wrap(new Gee.List<double?>[] {
                        new Gee.ArrayList<double?>.wrap(new double?[] { 0.41239079926595,  0.35758433938387, 0.18048078840183  }),
                        new Gee.ArrayList<double?>.wrap(new double?[] { 0.21263900587151,  0.71516867876775, 0.072192315360733 }),
                        new Gee.ArrayList<double?>.wrap(new double?[] { 0.019330818715591, 0.11919477979462, 0.95053215224966  }),
                    });
                }
                return MInv_;
            }
        }

		private static double RefX = 0.95045592705167;
		private static double RefY = 1.0;
		private static double RefZ = 1.089057750759878;

		private static double RefU = 0.19783000664283;
		private static double RefV = 0.46831999493879;

		private static double Kappa   = 903.2962962;
		private static double Epsilon = 0.0088564516;

		private static Gee.List<Gee.List<double?>> GetBounds(double L) {
			Gee.List<Gee.List<double?>> result = new Gee.ArrayList<Gee.List<double?>>();

			double sub1 = Math.pow(L + 16, 3) / 1560896;
			double sub2 = sub1 > Epsilon ? sub1 : L / Kappa;

			for (int c = 0; c < 3; ++c) {
				double m1 = M[c][0];
				double m2 = M[c][1]; 
				double m3 = M[c][2];

				for (int t = 0; t < 2; ++t) {
					var top1 = (284517 * m1 - 94839 * m3) * sub2;
					var top2 = (838422 * m3 + 769860 * m2 + 731718 * m1) * L * sub2 - 769860 * t * L;
					var bottom = (632260 * m3 - 126452 * m2) * sub2 + 126452 * t;

					result.add(new Gee.ArrayList<double?>.wrap(new double?[] { top1 / bottom, top2 / bottom }));
				}
			}

			return result;
		}

		private static double IntersectLineLine(double[] lineA, double[] lineB) {
			return (lineA[1] - lineB[1]) / (lineB[0] - lineA[0]);
		}

		private static double DistanceFromPole(double[] point) {
			return Math.sqrt(Math.pow(point[0], 2) + Math.pow(point[1], 2));
		}

		private static bool LengthOfRayUntilIntersect(double theta, double[] line, out double length) {
			length = line[1] / (Math.sin(theta) - line[0] * Math.cos(theta));

			return length >= 0;
		}

		private static double MaxSafeChromaForL(double L) {
			var bounds = GetBounds(L);
			double min = double.MAX;

			for (int i = 0; i < 2; ++i)	{
				var m1 = bounds[i][0]; 
				var b1 = bounds[i][1];
				var line = new double[] { m1, b1 };

				double x = IntersectLineLine(line, new double[] {-1 / m1, 0 });
				double length = DistanceFromPole(new double[] { x, b1 + x * m1 });

				min = double.min(min, length);
			}

			return min;
		}

		private static double MaxChromaForLH(double L, double H) {
			double hrad = H / 360 * Math.PI * 2;

			var bounds = GetBounds(L);
			double min = double.MAX;

			foreach (var bound_ in bounds) {
                double length;
                double[] bound = new double[bound_.size];
                for(int i = 0; i < bound_.size; i++) { bound[i] = bound_[i]; }

				if (LengthOfRayUntilIntersect(hrad, bound, out length)) {
					min = double.min(min, length);
				}
			}

			return min;
		}

		private static double DotProduct(Gee.List<double?> a, double[] b) {
			double sum = 0;

			for (int i = 0; i < a.size; ++i) {
				sum += a[i] * b[i];
			}

			return sum;
		}

		private static double Round(double value, int places) {
			double n = Math.pow(10, places);

			return Math.round(value * n) / n;
		}

		private static double FromLinear(double c) {
			if (c <= 0.0031308)	{
				return 12.92 * c;
			} else {
				return 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
			}
		}

		private static double ToLinear(double c) {
			if (c > 0.04045) {
				return Math.pow((c + 0.055) / (1 + 0.055), 2.4);
			} else {
				return c / 12.92;
			}
		}

		private static int[] RgbPrepare(double[] tuple) {
			for (int i = 0; i < tuple.length; ++i) {
				tuple[i] = Round(tuple[i], 3);
			}

			for (int i = 0; i < tuple.length; ++i) {
				double ch = tuple[i];

				if (ch < -0.0001 || ch > 1.0001) {
					return null; //throw new Error("Illegal rgb value: " + ch);
				}
			}

			var results = new int[tuple.length];

			for (int i = 0; i < tuple.length; ++i) {
				results[i] = (int) Math.round(tuple[i] * 255);
			}

			return results;
		}

		public static double[] XyzToRgb(double[] tuple) {
			return new double[]	{
				FromLinear(DotProduct(M[0], tuple)),
				FromLinear(DotProduct(M[1], tuple)),
				FromLinear(DotProduct(M[2], tuple)),
			};
		}

		public static double[] RgbToXyz(double[] tuple)	{
			var rgbl = new double[]	{
				ToLinear(tuple[0]),
				ToLinear(tuple[1]),
				ToLinear(tuple[2]),
			};

			return new double[]	{
				DotProduct(MInv[0], rgbl),
				DotProduct(MInv[1], rgbl),
				DotProduct(MInv[2], rgbl),
			};
		}

		private static double YToL(double Y) {
			if (Y <= Epsilon) {
				return (Y / RefY) * Kappa;
			} else {
				return 116 * Math.pow(Y / RefY, 1.0 / 3.0) - 16;
			}
		}

		private static double LToY(double L) {
			if (L <= 8) {
				return RefY * L / Kappa;
			} else {
				return RefY * Math.pow((L + 16) / 116, 3);
			}
		}

		public static double[] XyzToLuv(double[] tuple)	{
			double X = tuple[0];
			double Y = tuple[1];
			double Z = tuple[2];

			double varU = (4 * X) / (X + (15 * Y) + (3 * Z));
			double varV = (9 * Y) / (X + (15 * Y) + (3 * Z));

			double L = YToL(Y);

			if (L == 0) {
				return new double[] { 0, 0, 0 };
			}

			var U = 13 * L * (varU - RefU);
			var V = 13 * L * (varV - RefV);

			return new double [] { L, U, V };
		}

		public static double[] LuvToXyz(double[] tuple) {
			double L = tuple[0];
			double U = tuple[1];
			double V = tuple[2];

			if (L == 0) {
				return new double[] { 0, 0, 0 };
			}

			double varU = U / (13 * L) + RefU;
			double varV = V / (13 * L) + RefV;

			double Y = LToY(L);
			double X = 0 - (9 * Y * varU) / ((varU - 4) * varV - varU * varV);
			double Z = (9 * Y - (15 * varV * Y) - (varV * X)) / (3 * varV);

			return new double[] { X, Y, Z };
		}

		public static double[] LuvToLch(double[] tuple) {
			double L = tuple[0];
			double U = tuple[1];
			double V = tuple[2];

			double C = Math.pow(Math.pow(U, 2) + Math.pow(V, 2), 0.5);
			double Hrad = Math.atan2(V, U);

			double H = Hrad * 180.0 / Math.PI;

			if (H < 0) {
				H = 360 + H;
			}

			return new double[] { L, C, H };
		}

		public static double[] LchToLuv(double[] tuple) {
			double L = tuple[0];
			double C = tuple[1];
			double H = tuple[2];

			double Hrad = H / 360.0 * 2 * Math.PI;
			double U = Math.cos(Hrad) * C;
			double V = Math.sin(Hrad) * C;

			return new double [] { L, U, V };
		}

		public static double[] HsluvToLch(double[] tuple) {
			double H = tuple[0];
			double S = tuple[1]; 
			double L = tuple[2];

			if (L > 99.9999999) {
				return new double[] { 100, 0, H };
			}

			if (L < 0.00000001) {
				return new double[] { 0, 0, H };
			}

			double max = MaxChromaForLH(L, H);
			double C = max / 100 * S;

			return new double[] { L, C, H };
		}

		public static double[] LchToHsluv(double[] tuple) {
			double L = tuple[0];
			double C = tuple[1];
			double H = tuple[2];

			if (L > 99.9999999) {
				return new double[] { H, 0, 100 };
			}

			if (L < 0.00000001) {
				return new double[] { H, 0, 0 };
			}

			double max = MaxChromaForLH(L, H);
			double S = C / max * 100;

			return new double[] { H, S, L };
		}

		public static double[] HpluvToLch(double[] tuple) {
			double H = tuple[0];
			double S = tuple[1]; 
			double L = tuple[2];

			if (L > 99.9999999)	{
				return new double[] { 100, 0, H };
			}

			if (L < 0.00000001) {
				return new double[] { 0, 0, H };
			}

			double max = MaxSafeChromaForL(L);
			double C = max / 100 * S;

			return new double[] { L, C, H };
		}

		public static double[] LchToHpluv(double[] tuple) {
			double L = tuple[0];
			double C = tuple[1];
			double H = tuple[2];

			if (L > 99.9999999) {
				return new double[] { H, 0, 100 };
			}

			if (L < 0.00000001) {
				return new double[] { H, 0, 0 };
			}

			double max = MaxSafeChromaForL(L);
			double S = C / max * 100;

			return new double[] { H, S, L };
		}

		public static string RgbToHex(double[] tuple) {
			int[] prepared = RgbPrepare(tuple);

            return "#%.2x%.2x%.2x".printf(prepared[0], prepared[1], prepared[2]);
		}

		public static double[] HexToRgb(string hex) {
			return new double[]	{
				hex.substring(1, 2).to_long(null, 16) / 255.0,
				hex.substring(3, 2).to_long(null, 16) / 255.0,
				hex.substring(5, 2).to_long(null, 16) / 255.0,
			};
		}

		public static double[] LchToRgb(double[] tuple)	{
			return XyzToRgb(LuvToXyz(LchToLuv(tuple)));
		}

		public static double[] RgbToLch(double[] tuple)	{
			return LuvToLch(XyzToLuv(RgbToXyz(tuple)));
		}

		// Rgb <--> Hsluv(p)

		public static double[] HsluvToRgb(double[] tuple)	{
			return LchToRgb(HsluvToLch(tuple));
		}

		public static double[] RgbToHsluv(double[] tuple)	{
			return LchToHsluv(RgbToLch(tuple));
		}

		public static double[] HpluvToRgb(double[] tuple)	{
			return LchToRgb(HpluvToLch(tuple));
		}

		public static double[] RgbToHpluv(double[] tuple)	{
			return LchToHpluv(RgbToLch(tuple));
		}

		// Hex

		public static string HsluvToHex(double[] tuple) {
			return RgbToHex (HsluvToRgb (tuple));
		}

		public static string HpluvToHex(double[] tuple) {
			return RgbToHex (HpluvToRgb (tuple));
		}
			
		public static double[] HexToHsluv(string s)	{
			return RgbToHsluv (HexToRgb (s));
		}

		public static double[] HexToHpluv(string s)	{
			return RgbToHpluv (HexToRgb (s));
		}
    }
}