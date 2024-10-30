export const SelectText = {
  mounted() {
    this.el.addEventListener("mouseup", (e) => {
      let selection = window.getSelection();
      let text = selection.toString().trim();
      if (text) {
        this.pushEvent("text_selected", {
          text: text,
          chunkId: this.el.id
        });
      }
    });
  }
}