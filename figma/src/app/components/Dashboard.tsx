import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { Link } from "react-router";
import clsx from "clsx";

type DayStatus = "present" | "future" | "incomplete" | "empty";

interface Day {
  id: string;
  date: number;
  status: DayStatus;
  arrived?: string;
  left?: string;
  isCurrentMonth: boolean;
}

export function Dashboard() {
  const [selectedDay, setSelectedDay] = useState<Day | null>(null);

  // Generate 35 days (7 columns x 5 rows)
  const days: Day[] = Array.from({ length: 35 }).map((_, i) => {
    if (i < 3) {
      return { id: `prev-${i}`, date: 28 + i, status: "empty", isCurrentMonth: false };
    }
    if (i >= 3 && i < 34) {
      const date = i - 2;
      let status: DayStatus = "future";
      let arrived, left;
      
      if (date < 16) {
        const dayOfWeek = i % 7;
        if (dayOfWeek === 0 || dayOfWeek === 6) {
          status = "empty"; // weekend
        } else {
          status = "present";
          arrived = `09:${Math.floor(Math.random() * 30 + 10)}`;
          left = `18:${Math.floor(Math.random() * 45 + 10)}`;
        }
      } else if (date === 16) {
        status = "incomplete";
        arrived = "09:05";
      }

      return { id: `curr-${date}`, date, status, arrived, left, isCurrentMonth: true };
    }
    return { id: `next-${i}`, date: i - 33, status: "future", isCurrentMonth: false };
  });

  const presentCount = days.filter((d) => d.status === "present").length;
  const totalWorkingDays = 22;
  const progressPercent = (presentCount / totalWorkingDays) * 100;

  return (
    <div 
      className="relative min-h-screen bg-white text-gray-900 font-sans flex flex-col selection:bg-gray-100"
      onClick={() => setSelectedDay(null)}
    >
      {/* Top Navigation / Setup Link */}
      <div className="absolute top-8 right-8 z-10">
        <Link to="/setup" className="text-xs font-normal text-gray-400 hover:text-black transition-colors">
          Setup
        </Link>
      </div>

      {/* Floating Card Overlay - Flatter Design */}
      <AnimatePresence>
        {selectedDay && (selectedDay.status === "present" || selectedDay.status === "incomplete") && (
          <motion.div
            initial={{ opacity: 0, y: 5 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 5 }}
            transition={{ duration: 0.2 }}
            className="fixed top-32 left-1/2 -translate-x-1/2 z-50 py-4 px-6 rounded-xl bg-gray-50 border border-gray-200 pointer-events-none flex flex-col space-y-4 min-w-[220px] shadow-sm"
          >
            <div className="text-xs text-gray-500 font-medium">
              Nov {selectedDay.date}
            </div>
            <div className="flex flex-col space-y-2 w-full">
              {selectedDay.arrived && (
                <div className="flex justify-between w-full text-sm">
                  <span className="text-gray-500">Arrived</span>
                  <span className="font-mono text-black">{selectedDay.arrived}</span>
                </div>
              )}
              <div className="flex justify-between w-full text-sm">
                <span className="text-gray-500">Left</span>
                <span className={clsx("font-mono", selectedDay.left ? "text-black" : "text-gray-400")}>
                  {selectedDay.left || "--:--"}
                </span>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <main className="flex-1 flex flex-col pt-16 px-8 max-w-lg mx-auto w-full">
        
        {/* Header - Reduced Contrast */}
        <header className="mb-12 flex space-x-2 items-baseline justify-center">
          <h1 className="text-xl font-medium text-black">
            November
          </h1>
          <div className="text-sm font-normal text-gray-400">
            2026
          </div>
        </header>

        {/* 7x5 Grid */}
        <div className="flex-1 w-full flex flex-col justify-center">
          <div className="grid grid-cols-7 gap-y-8 gap-x-2 w-full">
            {/* Day Headers */}
            {["S", "M", "T", "W", "T", "F", "S"].map((day, i) => (
              <div key={`header-${i}`} className="text-center text-xs text-gray-400 mb-2">
                {day}
              </div>
            ))}
            
            {days.map((day) => (
              <div
                key={day.id}
                className="flex flex-col items-center justify-center space-y-2 cursor-pointer group"
                onClick={(e) => {
                  e.stopPropagation();
                  if (day.status !== 'empty') {
                    setSelectedDay(day);
                  }
                }}
              >
                <span
                  className={clsx(
                    "text-sm transition-colors duration-200",
                    !day.isCurrentMonth
                      ? "text-gray-200"
                      : day.status === "present" || day.status === "incomplete"
                      ? "text-black font-medium"
                      : "text-gray-400 group-hover:text-gray-600"
                  )}
                >
                  {day.date}
                </span>
                
                <div className="h-1.5 w-1.5 flex items-center justify-center">
                  {day.status === "present" && (
                    <motion.div 
                      layoutId={selectedDay?.id === day.id ? "active-dot" : undefined}
                      className="w-1.5 h-1.5 rounded-full bg-indigo-500" 
                    />
                  )}
                  {day.status === "future" && (
                    <div className="w-1 h-1 rounded-full bg-gray-200" />
                  )}
                  {day.status === "incomplete" && (
                    <div className="w-1.5 h-1.5 rounded-full border border-gray-400" />
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      </main>

      {/* Bottom Section: Summary - Flatter & Reduced Contrast */}
      <footer className="w-full pb-16 pt-8 px-8 max-w-lg mx-auto">
        <div className="flex flex-col space-y-2">
          <div className="flex items-baseline space-x-2">
            <h2 className="text-3xl font-medium text-black">
              {presentCount}
            </h2>
            <span className="text-base text-gray-600">
              days present
            </span>
          </div>
          <p className="text-sm text-gray-400">
            Out of {totalWorkingDays} working days this month
          </p>
          
          {/* Progress Line */}
          <div className="w-full h-[1px] bg-gray-100 mt-6 relative overflow-hidden">
            <motion.div 
              initial={{ width: 0 }}
              animate={{ width: `${progressPercent}%` }}
              transition={{ duration: 1, ease: "easeOut" }}
              className="absolute top-0 left-0 h-full bg-gray-800" 
            />
          </div>
        </div>
      </footer>
    </div>
  );
}
