export const SelectText = {
  mounted() {
    document.addEventListener("selectionchange", () => {
      let selection = window.getSelection();
      let text = selection.toString();
      
      if (text && selection && selection.rangeCount > 0) {
        const range = selection.getRangeAt(0); // we're kind of assuming the whole selection's within one node
        const element = selection.anchorNode.parentElement; // the parent element of the text node where the selection started
        const chunkId = element?.id;
        
        this.pushEvent("text_selected", {
          text: text,
          chunk_id: chunkId,
          start_offset: range.startOffset
        });
      }
    });
  }
}