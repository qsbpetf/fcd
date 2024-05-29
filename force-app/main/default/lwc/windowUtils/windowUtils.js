/* eslint-disable @lwc/lwc/no-document-query */

export const disableBodyScroll = () => {
  const body = document.querySelector("body");
  body.classList.remove("desktop");
  body.style.overflow = "hidden";
};

export const enableBodyScroll = () => {
  const body = document.querySelector("body");
  body.classList.add("desktop");
  body.style.overflow = "auto";
};