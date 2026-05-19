document.addEventListener('DOMContentLoaded', () => {
	let  chevrons = document.querySelectorAll(".drop_chevron");
	chevrons.forEach(el => el.addEventListener("click", toggleSubmenu));	
});

function toggleSubmenu() {
	let parent=this.closest(".navbar-item");
	let isOpen=parent.classList.contains("is-open");
	let openMen=document.querySelectorAll(".navbar-item.is-open");

	openMen.forEach(el => el.classList.remove("is-open"));

	if(!isOpen) {
		parent.classList.add("is-open");
	}
}