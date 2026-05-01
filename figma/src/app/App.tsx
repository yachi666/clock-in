import { RouterProvider } from "react-router";
import { router } from "./routes";

export default function App() {
  return (
    <div className="font-sans antialiased bg-white text-black min-h-screen selection:bg-indigo-100">
      <RouterProvider router={router} />
    </div>
  );
}
