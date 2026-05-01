import { createBrowserRouter } from "react-router";
import { Dashboard } from "./components/Dashboard";
import { Setup } from "./components/Setup";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Dashboard,
  },
  {
    path: "/setup",
    Component: Setup,
  }
]);
