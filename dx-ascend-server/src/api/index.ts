import { Router } from "express";
import healthRouter from "./health.routes";
import modbusRouter from "./modbus.routes";
import screensRouter from "./screens.routes";
import bindingsRouter from "./bindings.routes";
import runtimeRouter from "./runtime.routes"; 


const apiRouter = Router();

apiRouter.use(healthRouter);
apiRouter.use(modbusRouter);
apiRouter.use(screensRouter);
apiRouter.use(bindingsRouter);
apiRouter.use(runtimeRouter); 

export default apiRouter;
