// Maps the SF Symbol names used by the iOS app's IconPickerView to the
// closest available Lucide icon, grouped the same way so the web picker
// matches the iOS picker's categories.

import type { ReactNode } from "react";
import {
  Cross,
  Pill,
  Stethoscope,
  Heart,
  Bandage,
  Syringe,
  Thermometer,
  LifeBuoy,
  Wind,
  Activity,
  TestTube,
  Tent,
  Footprints,
  Backpack,
  Mountain,
  Sun,
  MoonStar,
  Flame,
  Droplet,
  Snowflake,
  Leaf,
  TreePine,
  Binoculars,
  Map,
  Navigation,
  Flashlight,
  Radio,
  Utensils,
  Coffee,
  ShoppingCart,
  ShoppingBasket,
  Refrigerator,
  CookingPot,
  Wine,
  Wrench,
  Hammer,
  Settings,
  Zap,
  Cable,
  Scissors,
  Ruler,
  Shield,
  AlertTriangle,
  Bell,
  Lock,
  Eye,
  Hand,
  Siren,
  User,
  Ear,
  ShoppingBag,
  Briefcase,
  Archive,
  Inbox,
  Folder,
  Package,
  Luggage,
  Tag,
  Star,
  Flag,
  Bookmark,
  Home,
  type LucideIcon,
} from "lucide-react";

export const ICON_MAP: Record<string, LucideIcon> = {
  "cross.case.fill": Cross,
  "cross.case": Cross,
  "pills.fill": Pill,
  stethoscope: Stethoscope,
  "heart.fill": Heart,
  "bandage.fill": Bandage,
  "syringe.fill": Syringe,
  thermometer: Thermometer,
  "staroflife.fill": LifeBuoy,
  "lungs.fill": Wind,
  "waveform.path.ecg": Activity,
  "cross.vial.fill": TestTube,

  "tent.fill": Tent,
  "figure.hiking": Footprints,
  "backpack.fill": Backpack,
  "mountain.2.fill": Mountain,
  "sun.max.fill": Sun,
  "moon.stars.fill": MoonStar,
  "flame.fill": Flame,
  "drop.fill": Droplet,
  snowflake: Snowflake,
  "leaf.fill": Leaf,
  "tree.fill": TreePine,
  "binoculars.fill": Binoculars,
  "map.fill": Map,
  "location.north.fill": Navigation,
  "flashlight.on.fill": Flashlight,
  "antenna.radiowaves.left.and.right": Radio,

  "fork.knife": Utensils,
  "cup.and.saucer.fill": Coffee,
  "cart.fill": ShoppingCart,
  "basket.fill": ShoppingBasket,
  "refrigerator.fill": Refrigerator,
  "frying.pan.fill": CookingPot,
  "wineglass.fill": Wine,
  "mug.fill": Coffee,

  "wrench.and.screwdriver.fill": Wrench,
  "hammer.fill": Hammer,
  "screwdriver.fill": Wrench,
  "gearshape.fill": Settings,
  "bolt.fill": Zap,
  "cable.connector": Cable,
  scissors: Scissors,
  "ruler.fill": Ruler,

  "shield.fill": Shield,
  "exclamationmark.triangle.fill": AlertTriangle,
  "bell.fill": Bell,
  "lock.fill": Lock,
  "eye.fill": Eye,
  "hand.raised.fill": Hand,
  "light.beacon.max.fill": Siren,
  sos: LifeBuoy,
  "figure.stand": User,
  "ear.and.waveform": Ear,

  "bag.fill": ShoppingBag,
  "briefcase.fill": Briefcase,
  "archivebox.fill": Archive,
  "tray.fill": Inbox,
  "folder.fill": Folder,
  "shippingbox.fill": Package,
  "suitcase.fill": Luggage,
  "tag.fill": Tag,
  "star.fill": Star,
  "flag.fill": Flag,
  "bookmark.fill": Bookmark,
  "house.fill": Home,
};

export const ICON_CATEGORIES: { name: string; icons: string[] }[] = [
  {
    name: "Medical",
    icons: [
      "cross.case.fill", "cross.case", "pills.fill", "stethoscope",
      "heart.fill", "bandage.fill", "syringe.fill", "thermometer",
      "staroflife.fill", "lungs.fill", "waveform.path.ecg", "cross.vial.fill",
    ],
  },
  {
    name: "Outdoor & Camping",
    icons: [
      "tent.fill", "figure.hiking", "backpack.fill", "mountain.2.fill",
      "sun.max.fill", "moon.stars.fill", "flame.fill", "drop.fill",
      "snowflake", "leaf.fill", "tree.fill", "binoculars.fill", "map.fill",
      "location.north.fill", "flashlight.on.fill",
      "antenna.radiowaves.left.and.right",
    ],
  },
  {
    name: "Food & Cooking",
    icons: [
      "fork.knife", "cup.and.saucer.fill", "cart.fill", "basket.fill",
      "refrigerator.fill", "frying.pan.fill", "wineglass.fill", "mug.fill",
    ],
  },
  {
    name: "Tools & Equipment",
    icons: [
      "wrench.and.screwdriver.fill", "hammer.fill", "screwdriver.fill",
      "gearshape.fill", "bolt.fill", "flashlight.on.fill",
      "antenna.radiowaves.left.and.right", "cable.connector", "scissors",
      "ruler.fill",
    ],
  },
  {
    name: "Safety & Emergency",
    icons: [
      "shield.fill", "exclamationmark.triangle.fill", "bell.fill",
      "lock.fill", "eye.fill", "hand.raised.fill", "light.beacon.max.fill",
      "sos", "figure.stand", "ear.and.waveform",
    ],
  },
  {
    name: "General",
    icons: [
      "bag.fill", "briefcase.fill", "archivebox.fill", "tray.fill",
      "folder.fill", "shippingbox.fill", "suitcase.fill", "tag.fill",
      "star.fill", "flag.fill", "bookmark.fill", "house.fill",
    ],
  },
];

export const KIT_COLORS: Record<string, string> = {
  teal: "#0d9488",
  red: "#ef4444",
  blue: "#3b82f6",
  orange: "#f97316",
  purple: "#a855f7",
  green: "#22c55e",
  pink: "#ec4899",
  indigo: "#6366f1",
};

export function KitIcon({
  icon,
  color,
  fallback,
  size = 16,
}: {
  icon: string | null | undefined;
  color: string | null | undefined;
  fallback?: ReactNode;
  size?: number;
}) {
  const Comp = icon ? ICON_MAP[icon] : undefined;
  const hex = KIT_COLORS[color ?? "teal"] ?? KIT_COLORS.teal;
  if (!Comp) return <>{fallback}</>;
  return <Comp size={size} color={hex} strokeWidth={2.25} />;
}
