document.addEventListener('DOMContentLoaded', () => {

	$(".drop_chevron").on("click",(e) => {
		$(e.target).closest(".navbar-item").toggleClass("is-open");			
	});
});