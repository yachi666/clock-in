import { motion } from "motion/react";
import { MapPin } from "lucide-react";
import { Link } from "react-router";
import { ImageWithFallback } from "./figma/ImageWithFallback";

export function Setup() {
  return (
    <div className="relative w-full h-screen overflow-hidden bg-[#F2F2F7]">
      {/* Map Background */}
      <div className="absolute inset-0">
        <ImageWithFallback
          src="https://images.unsplash.com/photo-1640444603313-3abef4d37fb4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtaW5pbWFsaXN0JTIwc3RyZWV0JTIwbWFwJTIwbGlnaHR8ZW58MXx8fHwxNzc3Mzc4MDQ1fDA&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
          alt="Map"
          className="w-full h-full object-cover opacity-60 grayscale contrast-125 brightness-110"
        />
        {/* Subtle gradient overlay to ensure text readability if needed, but we'll use a card */}
        <div className="absolute inset-0 bg-gradient-to-b from-white/30 via-transparent to-white/70 pointer-events-none" />
      </div>

      {/* Center Focus Element */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-[60%] flex items-center justify-center">
        {/* Pulsing rings */}
        <motion.div
          animate={{
            scale: [1, 2.5],
            opacity: [0.5, 0],
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            ease: "easeOut",
          }}
          className="absolute w-24 h-24 bg-indigo-500 rounded-full"
        />
        <motion.div
          animate={{
            scale: [1, 2],
            opacity: [0.3, 0],
          }}
          transition={{
            duration: 2,
            delay: 0.5,
            repeat: Infinity,
            ease: "easeOut",
          }}
          className="absolute w-24 h-24 bg-indigo-400 rounded-full"
        />
        
        {/* Center dot/pin */}
        <div className="relative z-10 w-6 h-6 bg-indigo-600 rounded-full border-4 border-white shadow-lg flex items-center justify-center">
          <div className="w-1.5 h-1.5 bg-white rounded-full" />
        </div>
      </div>

      {/* Bottom Interaction Area */}
      <div className="absolute bottom-0 left-0 right-0 p-6 pb-12 sm:pb-8 max-w-md mx-auto">
        <motion.div 
          initial={{ y: 50, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ duration: 0.5, ease: "easeOut", delay: 0.2 }}
          className="bg-white/70 backdrop-blur-xl border border-white/40 p-8 rounded-[2rem] shadow-[0_8px_32px_rgba(0,0,0,0.04)]"
        >
          <div className="flex flex-col items-center text-center space-y-4">
            <h1 className="text-2xl font-semibold tracking-tight text-gray-900 font-serif">
              Confirm Office Location
            </h1>
            
            <p className="text-[15px] leading-relaxed text-gray-500 max-w-[260px] mx-auto font-light">
              The app will automatically record your hours whenever you enter or leave this 100m radius.
            </p>

            <div className="pt-4 w-full">
              <Link 
                to="/" 
                className="block w-full py-4 px-6 bg-black text-white text-base font-medium rounded-full shadow-lg shadow-black/10 hover:scale-[1.02] active:scale-[0.98] transition-transform"
              >
                Set and Forget
              </Link>
            </div>
            
            <button className="text-xs text-gray-400 font-medium tracking-wide uppercase mt-2">
              Adjust Pin Manually
            </button>
          </div>
        </motion.div>
      </div>
    </div>
  );
}
