export const SelectText = {
  mounted() {
    this.el.addEventListener("mouseup", (e) => {
      const selection = window.getSelection();
      const text = selection.toString().trim();
      
      if (text) {
        this.pushEvent("text_selected", {
          text: text,
          paragraph_id: this.el.dataset.id,
          start: selection.anchorOffset,
          end: selection.focusOffset
        });
      }
    });
  }
};