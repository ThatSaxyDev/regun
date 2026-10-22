import React from "react";
import { Composition } from "remotion";
import { Trailer } from "./Trailer";
export const RemotionRoot: React.FC = () => (
  <Composition
    id="RegunTrailer"
    component={Trailer}
    durationInFrames={1320}
    fps={30}
    width={1920}
    height={1080}
  />
);
