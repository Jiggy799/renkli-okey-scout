const { getDefaultConfig } = require('expo/metro-config');
const { withNativeWind } = require('nativewind/metro');

const config = getDefaultConfig(__dirname);

// 1. NativeWind for TailwindCSS-in-JS
const withNW = withNativeWind(config, { input: './nativewind-env.d.ts' });

// 2. Vision Camera metro config (TFLite / worklets support)
let finalConfig = withNW;
try {
  const { getDefaultConfig: getVisionConfig } = require('react-native-vision-camera/metro-config');
  const visionConfig = getVisionConfig(__dirname);
  // Merge Vision Camera resolver/polyfills
  finalConfig = require('@react-native/metro-config').mergeConfig(visionConfig, withNW);
} catch {
  // react-native-vision-camera may not export metro-config in all versions — skip
}

module.exports = finalConfig;
